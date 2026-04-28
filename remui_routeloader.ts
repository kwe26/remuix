import type { Express, Request, Response } from 'express';
import { readdir } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export type RouteMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE' | 'ALL';

export type RoutedModule = {
  path: string;
  method?: RouteMethod;
  run: (req: Request, res: Response, ...args: unknown[]) => Promise<void> | void;
};

export type RoutedModuleLoader = RoutedModule | { default: RoutedModule };

export async function loadRoutedModules(routesDir = join(process.cwd(), 'routes')): Promise<RoutedModule[]> {
  const entries = await readdir(routesDir, { withFileTypes: true });
  const modules: RoutedModule[] = [];

  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith('.ts')) {
      continue;
    }

    const fullPath = resolve(routesDir, entry.name);
    const imported = (await import(pathToFileURL(fullPath).href)) as RoutedModuleLoader;
    const routed = 'default' in imported ? imported.default : imported;

    if (!routed || typeof routed.path !== 'string' || typeof routed.run !== 'function') {
      continue;
    }

    modules.push({
      method: routed.method ?? 'GET',
      path: routed.path,
      run: routed.run,
    });
  }

  return modules;
}

export async function registerRoutedModules(app: Express, routesDir?: string): Promise<RoutedModule[]> {
  const modules = await loadRoutedModules(routesDir);

  for (const routed of modules) {
    const method = routed.method ?? 'GET';
    const handler = (req: Request, res: Response) => routed.run(req, res);

    if (method === 'ALL') {
      app.all(routed.path, handler);
      continue;
    }

    const register = (app as unknown as Record<string, unknown>)[method.toLowerCase()];
    if (typeof register === 'function') {
      (register as (path: string, handler: (req: Request, res: Response) => void | Promise<void>) => void)(routed.path, handler);
    }
  }

  return modules;
}