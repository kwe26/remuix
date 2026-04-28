import express from 'express';
import cors from 'cors';
import {
    type JsonValue,
    SnackBar,
    clearRuntimeVars,
    hydrateRuntimeVarsFromContext,
    equate,
    getRuntimeVars,
    loadMaterialIcons,
    nav,
    remui,
    setPrefs,
    setVar,
    ui,
} from './remui';
import { initializeMaterialIcons, getAllIcons } from './remui_icons.ts';

const app = express();
app.use(cors());
app.use(express.json());
app.use(remui.ssr());

app.use(express.static('docs'));

app.get('/api/demo/users', (_req, res) => {
    res.json({
        data: [
            { name: 'Ada Lovelace', role: 'Analyst' },
            { name: 'Grace Hopper', role: 'Engineer' },
            { name: 'Margaret Hamilton', role: 'Architect' },
        ],
    });
});

app.get('/api/icons', (_req, res) => {
    const icons = getAllIcons();
    res.json({
        total: icons.length,
        icons,
    });
});

app.all('/ui/main', (req, res) => {
    clearRuntimeVars();
    hydrateRuntimeVarsFromContext(req.body);

    const callbacks = [
        SnackBar('Welcome to RemUI form demo'),
        {
            setSharedPref: 'page=main',
        },
    ];

    setVar('index', '0');
    setVar('name', '');
    setVar('password', '');
    setVar('rememberMe', false);
    setVar('loginPriority', 'normal');
    setVar('confidence', 50);
    setVar('meetingDate', '');
    setVar('meetingTime', '');
    setVar('meetingDateTime', '');

    const title = ui('Text', {
        text: 'Sign In Form',
        color: '#0d47a1',
    }).tag('h1');

    const subtitle = equate(
        'index',
        '0',
        {
            child: ui('Text', {
                text: 'Enter your credentials and submit callback #cb1001',
                color: '#37474f',
            }).tag('p'),
        },
    );

    const tokenState = equate(
        'prefs.token.isPresent',
        'true',
        {
            child: ui('Text', {
                text: 'A token exists in SharedPreferences.',
                color: '#1b5e20',
            }).tag('p'),
        },
    );

    const nameField = ui('TextField', {
        variable: 'name',
        labelText: 'Name',
        hintText: 'John Doe',
        leading: ui('Icon', { icon: "home", color: '#0d47a1' }),
        width: 320,
    });

    const passwordField = ui('TextField', {
        variable: 'password',
        labelText: 'Password',
        hintText: '********',
        obscureText: true,
        leading: ui('Icon', { icon: 'lock', color: '#0d47a1' }),
        width: 320,
    });

    const submitButton = ui('FilledButton', {
        color: '#00695c',
        action: {
            action: 'submit',
            id: '#cb1001',
            variables: [
                'name',
                'password',
                'rememberMe',
                'loginPriority',
                'confidence',
                'meetingDate',
                'meetingTime',
                'meetingDateTime',
            ],
        } as unknown as JsonValue,
        child: ui('Text', {
            text: 'Submit #cb1001',
            color: '#FFFFFF',
        }),
    });

    const rememberCheckbox = ui('Checkbox', {
        variable: 'rememberMe',
        label: 'Remember me on this device',
        subtitle: 'Stores your session preferences',
        tile: true,
    });

    const loginPriorityRadios = ui('Column', {
        crossAxis: 'start',
        children: [
            ui('Text', {
                text: 'Login priority',
                color: '#0d47a1',
                fontWeight: 'bold',
            }),
            ui('Radio', {
                variable: 'loginPriority',
                value: 'normal',
                label: 'Normal',
                tile: true,
            }),
            ui('Radio', {
                variable: 'loginPriority',
                value: 'strict',
                label: 'Strict',
                subtitle: 'Requires stronger checks',
                tile: true,
            }),
        ],
    });

    const confidenceSlider = ui('Slider', {
        variable: 'confidence',
        min: 0,
        max: 100,
        divisions: 10,
        showValue: true,
        title: 'Confidence',
        label: 'Confidence',
        activeColor: '#0d47a1',
    });

    const datePickers = ui('Column', {
        crossAxis: 'start',
        children: [
            ui('DatePicker', {
                variable: 'meetingDate',
                mode: 'date-only',
                labelText: 'Meeting Date',
                hintText: 'Select a date',
                width: 320,
            }),
            ui('SizedBox', { height: 8 }),
            ui('DatePicker', {
                variable: 'meetingTime',
                mode: 'time-only',
                labelText: 'Meeting Time',
                hintText: 'Select a time',
                width: 320,
            }),
            ui('SizedBox', { height: 8 }),
            ui('DatePicker', {
                variable: 'meetingDateTime',
                mode: 'both',
                labelText: 'Meeting Date & Time',
                hintText: 'Select date and time',
                width: 320,
            }),
        ],
    });

    const openDialogButton = ui('OutlinedButton', {
        color: '#0d47a1',
        action: nav('/ui/dialogTest', 'dialog'),
        child: ui('Text', {
            text: 'Open dialog form',
            color: '#0d47a1',
        }),
    });

    const openRemUI = ui('OutlinedButton', {
        color: '#0d47a1',
        action: nav('/ui/remui'),
        child: ui('Text', {
            text: 'Open RemUI',
            color: '#0d47a1',
        }),
    });

    const formCard = ui('Card', {
        child: ui('Padding', {
            padding: 16,
            child: ui('VerticalScroll', {
                child: ui('Column', {
                    crossAxis: 'start',
                    children: [
                        title,

                        subtitle,

                        tokenState,

                        nameField,

                        passwordField,

                        rememberCheckbox,

                        loginPriorityRadios,

                        confidenceSlider,

                        datePickers,

                        submitButton,

                        openDialogButton,
                        openRemUI
                    ],
                })
            }),
        }),
    });

    let CardForUser = ui('Card', {
        child: ui('Padding', {
            padding: 16,
            child: ui('Column', {
                crossAxis: 'center',
                children: [
                    // Avatar
                    ui('Center', {
                        child: ui('Avatar', {
                            imageUrl: 'http://localhost:3000/logo.jpg',
                            size: 150,
                            backgroundColor: '#0d47a1',
                            child: ui('Icon', { icon: 'verified', color: '#FFFFFF' }),
                        }).alt('RemUI profile avatar')
                    }),
                    ui('Text', { text: 'Welcome back, {prefs.name}!', color: '#0d47a1' }),
                    ui('Text', { text: 'Your token is: {prefs.token}', color: '#37474f' }),
                ],
            }),
        }),
    });

    const decideFormCard = equate(
        'index',
        '0',
        {
            child: formCard,
        },
    ).equate(
        'index',
        '1',
        {
            child: ui('SizedBox', { width: 300, child: CardForUser }),
        }
    );

    const SizedForm = ui('SizedBox', { height: 450, child: decideFormCard });

    const centeredContent = ui('Padding', {
        padding: 16,
        child: ui('Center', { child: SizedForm }),
    });

    const sidebar = ui('Sidebar', {
        variable: 'index',
        width: 300,
        color: '#eef2ff',
        title: 'Navigation',
        subtitle: 'RemUI Playground',
        headerIcon: 'dashboard_customize',
        accentColor: '#2454FF',
        itemRadius: 16,
        itemSpacing: 10,
        showChevron: true,
        footer: ui('Text', {
            text: 'Build 1.0.0',
            color: '#6B7280',
        }),
        items: [
            {
                icon: ui('Icon', { icon: 'home', color: '#0d47a1' }),
                label: 'Form',
                subtitle: 'Main demo screen',
                badge: 'NEW',
                action: {
                    type: 'setVar',
                    var: 'index',
                    value: '0',
                } as unknown as JsonValue,
            },
            {
                icon: ui('Icon', { icon: 'person', color: '#0d47a1' }),
                label: 'Profile',
                subtitle: 'Prefs + runtime vars',
                action: {
                    type: 'setVar',
                    var: 'index',
                    value: '1',
                } as unknown as JsonValue,
            },
            {
                icon: ui('Icon', { icon: 'open_in_new', color: '#0d47a1' }),
                label: 'Dialog',
                subtitle: 'Open as overlay',
                action: nav('/ui/dialogTest', 'dialog'),
            },
        ],
    }).tag('aside');

    const body = ui('SidebarWithUI', {
        sidebar,
        child: centeredContent,
    }).tag('section');

    const bottomNavigation = ui('RemBottomNavbar', {
        variable: 'index',
        currentIndex: '{index}',
        activeColor: '#0D47A1',
        noActiveColor: '#64748B',
        backgroundColor: '#FFFFFF',
        activeBackgroundColor: '#DBEAFE',
        itemSpacing: 10,
        iconSize: 22,
        items: [
            {
                icon: ui('Icon', { icon: 'home' }),
                label: 'Form',
                action: {
                    type: 'setVar',
                    var: 'index',
                    value: '0',
                } as unknown as JsonValue,
            },
            {
                icon: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Sample_User_Icon.png/64px-Sample_User_Icon.png',
                label: 'Profile',
                action: {
                    type: 'setVar',
                    var: 'index',
                    value: '1',
                } as unknown as JsonValue,
            },
            {
                icon: 'https://upload.wikimedia.org/wikipedia/commons/6/6b/Bitmap_VS_SVG.svg',
                label: 'Dialog',
                action: nav('/ui/dialogTest', 'dialog'),
            },
        ],
    });

    const screen = ui(
        'Scaffold',
        {
            page: '.main',
            appBar: ui('AppBar',
                {
                    title: ui('Text', { text: 'Main Page', color: '#FFFFFF' }),
                    backgroundColor: '#6200EE',
                    actions: [
                        ui('IconButton', {
                            icon: ui('Icon', { icon: 'widgets', color: '#FFFFFF' }),
                            onPressed: nav('/ui/remui'),
                        }),
                        ui('IconButton', {
                            icon: ui('Icon', { icon: 'screen_search_desktop', color: '#FFFFFF' }),
                            onPressed: nav('/ui/search'),
                        }),
                    ],
                }
            ),
            bottomNavigationBar: bottomNavigation,
            body,
        },
    )
        .meta('title', 'Main Page')
        .meta('description', 'RemUI playground main form');

    res.json({
        ...(screen as Record<string, JsonValue>),
        callbacks,
        vars: getRuntimeVars(),
    });
});

app.all('/ui/dialogTest', (req, res) => {
    clearRuntimeVars();
    hydrateRuntimeVarsFromContext(req.body);

    const callbacks = [SnackBar('Dialog form loaded')];

    setVar('dialogName', '');
    setVar('dialogEmail', '');
    setPrefs({ dialogName: '', dialogEmail: '' });

    const dialogBody = ui('Padding', {
        padding: 8,
        child: ui('Column', {
            crossAxis: 'start',
            children: [
                ui('Text', {
                    text: 'This dialog stays above the current page.',
                    color: '#37474f',
                }),

                ui('TextField', {
                    variable: 'dialogName',
                    labelText: 'Display name',
                    hintText: 'Rem User',
                    leading: ui('Icon', { icon: 'badge', color: '#0d47a1' }),
                    width: 320,
                }),

                ui('TextField', {
                    variable: 'dialogEmail',
                    labelText: 'Email',
                    hintText: 'rem@example.com',
                    leading: ui('Icon', { icon: 'mail', color: '#0d47a1' }),
                    width: 320,
                }),
            ],
        }),
    });

    const dialog = ui('Dialog', {
        page: '.diag',
        title: ui('Text', {
            text: 'Dialog Form',
            color: '#0d47a1',
        }),
        body: ui('SizedBox', { height: 200, child: dialogBody }),
        actions: [
            ui('TextButton', {
                color: '#0d47a1',
                action: {
                    action: 'submit',
                    id: '#rfrm10',
                    variables: ['dialogName', 'dialogEmail'],
                } as unknown as JsonValue,
                child: ui('Text', {
                    text: 'Save',
                    color: '#0d47a1',
                }),
            }),
            ui('TextButton', {
                color: '#b42318',
                action: {
                    action: 'submit',
                    id: '#clearToken',
                } as unknown as JsonValue,
                child: ui('Text', {
                    text: 'Clear token',
                    color: '#b42318',
                }),
            }),
        ],
    })
        .meta('title', 'Dialog Form')
        .meta('description', 'Overlay dialog form example');

    res.json({
        ...(dialog as Record<string, JsonValue>),
        callbacks,
        vars: getRuntimeVars(),
    });
});

app.all('/ui/search', (req, res) => {
    clearRuntimeVars();
    hydrateRuntimeVarsFromContext(req.body);

    const callbacks = [SnackBar('Search page ready')];

    setVar('searchIndex', '0');
    setVar('searchQuery', 'navigation');
    setVar('searchTab', '0');
    setVar('searchChoice', 'light');
    setVar('searchDelayed', 'pending');

    const delayedSendBack = remui
        .sendBack()
        .timeout(1000)
        .setVar('searchDelayed', 'ready')
        .setSharedPref('searchDelayed=ready')
        .remSharedPref('dialogEmail');

    const searchHeader = ui('Card', {
        child: ui('Padding', {
            padding: 16,
            child: ui('Column', {
                crossAxis: 'start',
                children: [
                    ui('Text', {
                        text: 'Search',
                        color: '#0d47a1',
                        fontSize: 24,
                        fontWeight: 'bold',
                    }),
                    ui('SizedBox', { height: 8 }),
                    ui('Text', {
                        text: 'A NavigationRail-based page for exploring widgets and docs.',
                        color: '#455a64',
                    }),

                    ui('TextField', {
                        variable: 'searchQuery',
                        labelText: 'Search widgets or docs',
                        hintText: 'Try rail, sidebar, dialog, callbacks',
                        leading: ui('Icon', {
                            icon: 'search',
                            color: '#0d47a1',
                        }),
                        width: 420,
                    }),
                ],
            }),
        }),
    });

    const controlsDemo = ui('Card', {
        child: ui('Padding', {
            padding: 16,
            child: ui('Column', {
                crossAxis: 'start',
                children: [
                    ui('Text', {
                        text: 'Tabs and Radio',
                        color: '#0d47a1',
                        fontSize: 18,
                        fontWeight: 'bold',
                    }),

                    ui('SizedBox', {
                        height: 220,
                        child: ui('Tabs', {
                            variable: 'searchTab',
                            tabs: [
                                { label: 'Overview' },
                                { label: 'Widgets' },
                                { label: 'Docs' },
                            ],
                            children: [
                                ui('Text', {
                                    text: 'Overview tab content',
                                    color: '#455a64',
                                }),
                                ui('Text', {
                                    text: 'Widget registry content',
                                    color: '#455a64',
                                }),
                                ui('Text', {
                                    text: 'Docs content',
                                    color: '#455a64',
                                }),
                            ],
                        }),
                    }),

                    ui('Text', {
                        text: 'Theme choice',
                        color: '#0d47a1',
                        fontWeight: 'bold',
                    }),
                    ui('Radio', {
                        variable: 'searchChoice',
                        value: 'light',
                        label: 'Light',
                        subtitle: 'Bright UI',
                        tile: true,
                    }),
                    ui('Radio', {
                        variable: 'searchChoice',
                        value: 'dark',
                        label: 'Dark',
                        subtitle: 'Contrast UI',
                        tile: true,
                    }),
                ],
            }),
        }),
    });

    const searchResults = equate(
        'searchIndex',
        '0',
        {
            child: ui('Card', {
                child: ui('Padding', {
                    padding: 16,
                    child: ui('Column', {
                        crossAxis: 'start',
                        children: [
                            ui('Text', {
                                text: 'Widget discovery',
                                color: '#0d47a1',
                                fontSize: 18,
                                fontWeight: 'bold',
                            }),
                            ui('SizedBox', { height: 8 }),
                            ui('Text', {
                                text: 'Use NavigationRail for desktop and tablet navigation shells.',
                                color: '#455a64',
                            }),

                            ui('Text', {
                                text: 'Suggested docs: widgets.html#navigationrail',
                                color: '#1b5e20',
                            }),
                        ],
                    }),
                }),
            }),
        },
    ).equate(
        'searchIndex',
        '1',
        {
            child: ui('Card', {
                child: ui('Padding', {
                    padding: 16,
                    child: ui('Column', {
                        crossAxis: 'start',
                        children: [
                            ui('Text', {
                                text: 'Docs and examples',
                                color: '#0d47a1',
                                fontSize: 18,
                                fontWeight: 'bold',
                            }),
                            ui('SizedBox', { height: 8 }),
                            ui('Text', {
                                text: 'The widgets reference has Sidebar, SidebarWithUI, and NavigationRail schema examples.',
                                color: '#455a64',
                            }),

                            ui('Text', {
                                text: 'Open docs/remui.html for the design overview.',
                                color: '#1b5e20',
                            }),
                        ],
                    }),
                }),
            }),
        },
    ).equate(
        'searchIndex',
        '2',
        {
            child: ui('Card', {
                child: ui('Padding', {
                    padding: 16,
                    child: ui('Column', {
                        crossAxis: 'start',
                        children: [
                            ui('Text', {
                                text: 'Callbacks and navigation',
                                color: '#0d47a1',
                                fontSize: 18,
                                fontWeight: 'bold',
                            }),
                            ui('SizedBox', { height: 8 }),
                            ui('Text', {
                                text: 'This page is wired so you can attach actions to destinations, set variables, and route to dialogs.',
                                color: '#455a64',
                            }),

                            ui('Text', {
                                text: 'Try the Dialog page from the main screen too.',
                                color: '#1b5e20',
                            }),
                        ],
                    }),
                }),
            }),
        },
    );

    const railDestinations = [
        {
            icon: ui('Icon', { icon: 'search' }),
            selectedIcon: ui('Icon', { icon: 'search' }),
            label: 'Discovery',
            subtitle: 'Widgets and search',
            action: {
                type: 'setVar',
                var: 'searchIndex',
                value: '0',
            } as unknown as JsonValue,
        },
        {
            icon: ui('Icon', { icon: 'menu_book' }),
            selectedIcon: ui('Icon', { icon: 'menu_book' }),
            label: 'Docs',
            subtitle: 'Reference pages',
            action: {
                type: 'setVar',
                var: 'searchIndex',
                value: '1',
            } as unknown as JsonValue,
        },
        {
            icon: ui('Icon', { icon: 'chat_bubble' }),
            selectedIcon: ui('Icon', { icon: 'chat_bubble' }),
            label: 'Callbacks',
            subtitle: 'Behavior patterns',
            action: {
                type: 'setVar',
                var: 'searchIndex',
                value: '2',
            } as unknown as JsonValue,
        },
    ];

    const navigationRail = ui('NavigationRail', {
        variable: 'searchIndex',
        extended: false,
        autoCollapse: true,
        autoCollapseBreakpoint: 820,
        compactLabelType: 'selected',
        minWidth: 72,
        minExtendedWidth: 232,
        useIndicator: true,
        backgroundColor: '#eef2ff',
        indicatorColor: '#dbeafe',
        selectedIconColor: '#0d47a1',
        unselectedIconColor: '#607d8b',
        selectedLabelColor: '#0d47a1',
        unselectedLabelColor: '#455a64',
        destinations: railDestinations,
    });

    const searchBody = ui('SidebarWithUI', {
        sidebar: navigationRail,
        contentPadding: 16,
        backgroundColor: '#f8fafc',
        child: ui('Column', {
            crossAxis: 'start',
            children: [
                ui('Text', {
                    text: 'NavigationRail sample',
                    color: '#0d47a1',
                    fontSize: 16,
                    fontWeight: 'bold',
                }),
                ui('SizedBox', { height: 8 }),
                ui('Text', {
                    text: 'Use the rail toggle above the rail. It auto-collapses on small screens.',
                    color: '#607d8b',
                    fontSize: 12,
                }),

                controlsDemo,

                ui('Timeout', {
                    data: delayedSendBack as unknown as JsonValue,
                }),
                ui('Text', {
                    text: 'Delayed state: {searchDelayed}',
                    color: '#1b5e20',
                }),
                ui('SizedBox', { height: 10 }),
                searchHeader,

                searchResults,
            ],
        }),
    }).tag('section');

    const screen = ui('Scaffold', {
        page: '/ui/search',
        appBar: ui('AppBar', {
            title: ui('Text', { text: 'Search', color: '#FFFFFF' }),
            backgroundColor: '#0d47a1',
            actions: [
                ui('IconButton', {
                    icon: ui('Icon', { icon: 'home', color: '#FFFFFF' }),
                    onPressed: nav('/ui/main'),
                }),
            ],
        }),
        body: searchBody,
    })
        .meta('title', 'Search')
        .meta('description', 'NavigationRail sample and widget discovery');

    res.json({
        ...(screen as Record<string, JsonValue>),
        callbacks,
        vars: getRuntimeVars(),
    });
});

app.all('/ui/remui', (req, res) => {
    clearRuntimeVars();
    hydrateRuntimeVarsFromContext(req.body);

    const callbacks = [SnackBar('RemUI component page ready')];

    setVar('remBottomIndex', '0');
    setVar('remNavSearch', '');
    setVar('remNavMode', 'dashboard');

    const drops = ui('RemDropdowns', {
        dropdowns: [
            {
                name: 'Dashboard',
                icon: ui('Icon', { icon: 'dashboard' }),
                action: {
                    type: 'setVar',
                    var: 'remNavMode',
                    value: 'dashboard',
                } as unknown as JsonValue,
            },
            {
                name: 'Products',
                icon: ui('Icon', { icon: 'inventory_2' }),
                dropdowns: [
                    {
                        name: 'Catalog',
                        icon: ui('Icon', { icon: 'list_alt' }),
                        action: {
                            type: 'setVar',
                            var: 'remNavMode',
                            value: 'catalog',
                        } as unknown as JsonValue,
                    },
                    {
                        name: 'Stock',
                        icon: ui('Icon', { icon: 'store' }),
                        dropdowns: [
                            {
                                name: 'Warehouse A',
                                icon: ui('Icon', { icon: 'warehouse' }),
                                action: {
                                    type: 'setVar',
                                    var: 'remNavMode',
                                    value: 'stock_a',
                                } as unknown as JsonValue,
                            },
                            {
                                name: 'Warehouse B',
                                icon: ui('Icon', { icon: 'warehouse' }),
                                action: {
                                    type: 'setVar',
                                    var: 'remNavMode',
                                    value: 'stock_b',
                                } as unknown as JsonValue,
                            },
                        ],
                    },
                ],
            },
            {
                name: 'Settings',
                icon: ui('Icon', { icon: 'settings' }),
                dropdowns: [
                    {
                        name: 'General',
                        icon: ui('Icon', { icon: 'tune' }),
                        action: {
                            type: 'setVar',
                            var: 'remNavMode',
                            value: 'general',
                        } as unknown as JsonValue,
                    },
                    {
                        name: 'Security',
                        icon: ui('Icon', { icon: 'security' }),
                        action: {
                            type: 'setVar',
                            var: 'remNavMode',
                            value: 'security',
                        } as unknown as JsonValue,
                    },
                    {
                        name: 'API',
                        icon: ui('Icon', { icon: 'api' }),
                        dropdowns: [
                            {
                                name: 'Tokens',
                                icon: ui('Icon', { icon: 'vpn_key' }),
                                action: {
                                    type: 'setVar',
                                    var: 'remNavMode',
                                    value: 'api_tokens',
                                } as unknown as JsonValue,
                            },
                            {
                                name: 'Webhooks',
                                icon: ui('Icon', { icon: 'webhook' }),
                                action: {
                                    type: 'setVar',
                                    var: 'remNavMode',
                                    value: 'api_webhooks',
                                } as unknown as JsonValue,
                            },
                        ],
                    },
                ],
            },
        ],
    });

    const remNavbar = ui('RemNavbar', {
        logo: ui('Image', {
            src: 'http://localhost:3000/logo.jpg',
            width: 30,
            height: 30,
            fit: 'cover',
        }),
        title: ui('Text', {
            text: 'RemUI Professional Navbar',
            color: '#0F172A',
            fontWeight: 'bold',
        }),
        isAppBar: true,
        searchTextField: ui('TextField', {
            variable: 'remNavSearch',
            hintText: 'Search pages, products, users...',
            leading: ui('Icon', { icon: 'search', color: '#64748B' }),
            width: 280,
        }),
        dropdowns: drops,
        backgroundColor: '#FFFFFF',
        borderColor: '#E2E8F0',
        titleColor: '#0F172A',
        compactBreakpoint: 800,
        paddingX: 12,
        paddingY: 10,
    });

    const remBottom = ui('RemBottomNavbar', {
        variable: 'remBottomIndex',
        currentIndex: '{remBottomIndex}',
        activeColor: '#0D47A1',
        noActiveColor: '#64748B',
        backgroundColor: '#FFFFFF',
        activeBackgroundColor: '#DBEAFE',
        itemSpacing: 10,
        iconSize: 22,
        items: [
            {
                icon: ui('Icon', { icon: 'home' }),
                label: 'Home',
                action: {
                    type: 'setVar',
                    var: 'remBottomIndex',
                    value: '0',
                } as unknown as JsonValue,
            },
            {
                icon: ui('Icon', { icon: 'inventory_2' }),
                label: 'Products',
                action: {
                    type: 'setVar',
                    var: 'remBottomIndex',
                    value: '1',
                } as unknown as JsonValue,
            },
            {
                icon: 'https://upload.wikimedia.org/wikipedia/commons/thumb/9/99/Sample_User_Icon.png/64px-Sample_User_Icon.png',
                label: 'Customers',
                action: {
                    type: 'setVar',
                    var: 'remBottomIndex',
                    value: '2',
                } as unknown as JsonValue,
            },
            {
                icon: 'https://upload.wikimedia.org/wikipedia/commons/6/6b/Bitmap_VS_SVG.svg',
                label: 'SVG Icon',
                action: {
                    type: 'setVar',
                    var: 'remBottomIndex',
                    value: '3',
                } as unknown as JsonValue,
            },
            {
                icon: ui('Icon', { icon: 'settings' }),
                label: 'Settings',
                action: {
                    type: 'setVar',
                    var: 'remBottomIndex',
                    value: '4',
                } as unknown as JsonValue,
            },
            {
                icon: ui('Icon', { icon: 'help' }),
                label: 'Support',
                action: {
                    type: 'setVar',
                    var: 'remBottomIndex',
                    value: '5',
                } as unknown as JsonValue,
            },
        ],
    });

    const foreachUsers = ui('foreach', {
        url: 'GET:http://localhost:3000/api/demo/users',
        body: {},
        headers: {
            'x-remui-demo': 'foreach',
        },
        toForeach: 'data',
        spacing: 8,
        loading: ui('Text', { text: 'Loading users...', color: '#64748B' }),
        fallback: ui('Text', { text: 'No users found.', color: '#64748B' }),
        data: ui('Card', {
            child: ui('Padding', {
                padding: 12,
                child: ui('Row', {
                    mainAxis: 'spaceBetween',
                    children: [
                        ui('Text', {
                            text: '$name$',
                            color: '#0F172A',
                            fontWeight: 'bold',
                        }),
                        ui('Text', {
                            text: '$role$',
                            color: '#475467',
                        }),
                    ],
                }),
            }),
        }),
    });

    const body = ui('VerticalScroll', {
        child: ui('Padding', {
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
                                        text: 'RemNavbar + Recursive Dropdowns Demo',
                                        color: '#0D47A1',
                                        fontSize: 18,
                                        fontWeight: 'bold',
                                    }),
                                    ui('SizedBox', { height: 8 }),
                                    ui('Text', {
                                        text: 'Current mode: {remNavMode}',
                                        color: '#1B5E20',
                                    }),
                                    ui('Text', {
                                        text: 'Search text: {remNavSearch}',
                                        color: '#455A64',
                                    }),
                                    ui('SizedBox', { height: 8 }),
                                    ui('Text', {
                                        text: 'Resize small screens to see compact 3-line behavior.',
                                        color: '#607D8B',
                                    }),
                                    ui('SizedBox', { height: 14 }),
                                    ui('Text', {
                                        text: 'Foreach URLRequest demo (data from /api/demo/users):',
                                        color: '#0D47A1',
                                        fontWeight: 'bold',
                                    }),
                                    ui('SizedBox', { height: 8 }),
                                    foreachUsers,
                                ],
                            }),
                        }),
                    }),
                ],
            }),
        }),
    });

    const screen = ui('Scaffold', {
        page: '/ui/remui',
        appBar: remNavbar,
        body,
        bottomNavigationBar: remBottom,
    })
        .meta('title', 'RemUI Components')
        .meta('description', 'RemNavbar, RemDropdowns, and RemBottomNavbar showcase');

    res.json({
        ...(screen as Record<string, JsonValue>),
        callbacks,
        vars: getRuntimeVars(),
    });
});

app.post('/ui/callbacks', (req, res) => {
    const callbackId = typeof req.body?.id === 'string' ? req.body.id.trim() : '';

    if (!callbackId) {
        res.status(400).json({
            error: 'Missing callback id. Expected body.id like "#cb1001"',
        });
        return;
    }

    const callback = ui.getCallback(req, res, callbackId);
    const data = callback.data<{ variables?: Record<string, unknown> }>();
    const variables = data.variables && typeof data.variables === 'object'
        ? data.variables
        : {};

    if (callbackId === '#cb1001') {
        const submittedKeys = Object.keys(variables);
        callback
            .add(SnackBar(`WEWEEWEWEEEWEE! Received variables: ${submittedKeys.join(', ')}`))
            .setVar('index', '1')
            .setSharedPref(`token=${Math.random().toString(36).substring(2)}&name=${variables.name ?? 'unknown'}`)
            .reloadRetain()
            .send();
        return;
    }

    if (callbackId === '#rfrm10') {
        callback
            .add(SnackBar(`Dialog saved for ${variables.dialogName ?? 'unknown'}`))
            .setSharedPref(`dialogName=${variables.dialogName ?? ''}&dialogEmail=${variables.dialogEmail ?? ''}`)
            .closeDialog()
            .send();
        return;
    }

    if (callbackId === '#clearToken') {
        callback
            .add(SnackBar('Token removed from SharedPreferences'))
            .remSharedPref('token')
            
            .send();
        return;
    }

    callback
        .add(SnackBar(`Unhandled callback id: ${callbackId}`))
        .send(404);
});

app.use(remui.notFound());

async function startServer(): Promise<void> {
    await loadMaterialIcons();
    await initializeMaterialIcons();
    app.listen(3000, () => {
        console.log('Server is running on port 3000');
    });
}

void startServer();