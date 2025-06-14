// Mock global objects for testing environment
global.fetch = jest.fn();

// Mock navigator with proper structure
Object.defineProperty(global, 'navigator', {
    value: {
        share: jest.fn(),
        canShare: jest.fn(),
        clipboard: {
            writeText: jest.fn(),
        },
    },
    writable: true,
});

// Mock URL constructor
global.URL = class MockURL {
    constructor(public url: string) {
        this.url = url;
    }
    toString() {
        return this.url;
    }
} as any;

// Mock window.open
Object.defineProperty(global, 'window', {
    value: {
        open: jest.fn(),
    },
    writable: true,
});

// Mock alert function
global.alert = jest.fn();

// Mock atob for base64 decoding
global.atob = jest.fn((str: string) => {
    return Buffer.from(str, 'base64').toString('binary');
});

// Mock File constructor with proper prototype chain
global.File = class MockFile {
    name: string;
    type: string;
    size: number;
    parts: any[];

    constructor(parts: any[], filename: string, options?: { type?: string }) {
        this.name = filename;
        this.type = options?.type || 'application/octet-stream';
        this.size = parts.reduce((acc: number, part: any) => acc + (part.length || 0), 0);
        this.parts = parts;
    }
} as any;

// Mock Blob constructor  
global.Blob = class MockBlob {
    type: string;
    size: number;
    parts: any[];

    constructor(parts: any[], options?: { type?: string }) {
        this.type = options?.type || 'application/octet-stream';
        this.size = parts.reduce((acc: number, part: any) => acc + (part.length || 0), 0);
        this.parts = parts;
    }
} as any;

// Mock URLSearchParams
global.URLSearchParams = jest.fn().mockImplementation((init) => {
    const params = new Map();
    if (typeof init === 'string') {
        // Parse query string
        init.split('&').forEach(param => {
            const [key, value] = param.split('=');
            if (key) params.set(key, value || '');
        });
    }
    return {
        append: jest.fn((key, value) => params.set(key, value)),
        toString: jest.fn(() => {
            const pairs: string[] = [];
            params.forEach((value, key) => {
                pairs.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
            });
            return pairs.join('&');
        }),
    };
}) as any;



// Mock Capacitor plugin registration with proper handling of dynamic imports
jest.mock('@capacitor/core', () => ({
    registerPlugin: jest.fn((name, implementation) => {
        // Return a mock plugin with a share method
        return {
            share: jest.fn().mockResolvedValue(undefined),
        };
    }),
    WebPlugin: class MockWebPlugin {
        constructor() { }
    },
    Capacitor: {
        isNativePlatform: jest.fn(() => false),
        getPlatform: jest.fn(() => 'web'),
    },
}));

// Clear all mocks before each test
beforeEach(() => {
    jest.clearAllMocks();
}); 