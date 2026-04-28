import type { Request, Response } from 'express';
import {
  type JsonValue,
  SnackBar,
  clearRuntimeVars,
  hydrateRuntimeVarsFromContext,
  getRuntimeVars,
  nav,
  setVar,
  ui,
} from '../import';

type RoutedPageModule = {
  path: string;
  method: 'GET' | 'POST';
  run: (req: Request, res: Response, ...args: unknown[]) => Promise<void> | void;
};

const routedPage: RoutedPageModule = {
  path: '/ui/main',
  method: 'GET',
  run: async (req: Request, res: Response): Promise<void> => {
    clearRuntimeVars();
    hydrateRuntimeVarsFromContext(req.body);

    const callbacks = [SnackBar('Routed page ready')];

    setVar('index', '0');
    setVar('name', '');

    const screen = ui('Scaffold', {
      page: '/ui/main',
      appBar: ui('AppBar', {
        title: ui('Text', { text: 'Routed Main', color: '#FFFFFF' }),
        backgroundColor: '#0d47a1',
        actions: [
          ui('IconButton', {
            icon: ui('Icon', { icon: 'home', color: '#FFFFFF' }),
            onPressed: nav('/ui/main'),
          }),
        ],
      }),
      body: ui('Padding', {
        padding: 16,
        child: ui('Column', {
          crossAxis: 'start',
          children: [
            ui('Card', {
              child: ui('Padding', {
                padding: 16,
                child: ui('Column', {
                  crossAxis: 'start',
                  children: [
                    ui('Text', {
                      text: 'Routed RemUI sample',
                      color: '#0d47a1',
                      fontSize: 20,
                      fontWeight: 'bold',
                    }),
                    ui('SizedBox', { height: 8 }),
                    ui('Text', {
                      text: 'This file lives under ./routes/*.ts and imports everything from ./import.',
                      color: '#455a64',
                    }),
                    ui('SizedBox', { height: 8 }),
                    ui('Text', {
                      text: 'Current name: {name}',
                      color: '#1b5e20',
                    }),
                  ],
                }),
              }),
            }),
            ui('SizedBox', { height: 12 }),
            ui('TextField', {
              variable: 'name',
              hintText: 'Type your name',
              labelText: 'Name',
              width: 320,
            }),
            ui('SizedBox', { height: 12 }),
            ui('Text', {
              text: 'Server route data can still use JSON helpers like {prefs.token}.',
              color: '#607d8b',
            }),
          ],
        }),
      }),
    })
      .meta('title', 'Routed Main')
      .meta('description', 'Example route module for ./routes/*.ts');

    res.json({
      ...(screen as Record<string, JsonValue>),
      callbacks,
      vars: getRuntimeVars(),
    });
  },
};

export default routedPage;