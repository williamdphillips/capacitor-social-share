#!/usr/bin/env node

const { execSync } = require('child_process');
const path = require('path');

// Colors for console output
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    green: '\x1b[32m',
    red: '\x1b[31m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function runCommand(command, description) {
    log(`\n📦 ${description}`, 'blue');
    try {
        const output = execSync(command, { encoding: 'utf8', stdio: 'inherit' });
        log(`✅ ${description} completed successfully`, 'green');
        return true;
    } catch (error) {
        log(`❌ ${description} failed`, 'red');
        console.error(error.message);
        return false;
    }
}

function main() {
    const args = process.argv.slice(2);
    const testType = args[0] || 'all';

    log('🧪 Capacitor Social Share Plugin Test Suite', 'bright');
    log('============================================', 'bright');

    // Install dependencies if needed
    if (!require('fs').existsSync(path.join(__dirname, '../node_modules'))) {
        log('\n📦 Installing dependencies...', 'yellow');
        runCommand('npm install', 'Dependency installation');
    }

    // Run specific test suites based on argument
    switch (testType) {
        case 'definitions':
            runCommand('npm test -- tests/definitions.test.ts', 'TypeScript Definitions Tests');
            break;

        case 'web':
            runCommand('npm test -- tests/web.test.ts', 'Web Platform Tests');
            break;

        case 'native':
            runCommand('npm test -- tests/native.test.ts', 'Native Platform Tests');
            break;

        case 'integration':
            runCommand('npm test -- tests/integration.test.ts', 'Integration Tests');
            break;

        case 'examples':
            runCommand('npm test -- tests/examples.test.ts', 'Usage Examples Tests');
            break;

        case 'coverage':
            runCommand('npm run test:coverage', 'Test Coverage Report');
            break;

        case 'lint':
            runCommand('npm run lint', 'Code Linting');
            break;

        case 'help':
            log('\nUsage: node test-runner.js [test-type]', 'bright');
            log('\nAvailable test types:', 'yellow');
            log('  all         - Run all test suites (default)');
            log('  definitions - Test TypeScript definitions');
            log('  web         - Test web platform implementation');
            log('  native      - Test native platform implementations');
            log('  integration - Test plugin integration');
            log('  examples    - Test usage examples');
            log('  coverage    - Generate test coverage report');
            log('  lint        - Run code linting');
            log('  help        - Show this help message');
            break;

        case 'all':
        default:
            log('\n🚀 Running all test suites...', 'yellow');

            const testSuites = [
                { cmd: 'npm run lint', desc: 'Code Linting' },
                { cmd: 'npm test -- tests/definitions.test.ts', desc: 'TypeScript Definitions Tests' },
                { cmd: 'npm test -- tests/web.test.ts', desc: 'Web Platform Tests' },
                { cmd: 'npm test -- tests/native.test.ts', desc: 'Native Platform Tests' },
                { cmd: 'npm test -- tests/integration.test.ts', desc: 'Integration Tests' },
                { cmd: 'npm test -- tests/examples.test.ts', desc: 'Usage Examples Tests' },
            ];

            let passedTests = 0;

            for (const suite of testSuites) {
                if (runCommand(suite.cmd, suite.desc)) {
                    passedTests++;
                }
            }

            log('\n📊 Test Summary', 'bright');
            log(`✅ Passed: ${passedTests}/${testSuites.length}`, passedTests === testSuites.length ? 'green' : 'yellow');

            if (passedTests === testSuites.length) {
                log('\n🎉 All tests passed! Your plugin is ready for production.', 'green');
            } else {
                log('\n⚠️  Some tests failed. Please review the output above.', 'yellow');
                process.exit(1);
            }

            // Generate coverage report
            log('\n📈 Generating coverage report...', 'blue');
            runCommand('npm run test:coverage', 'Coverage Report Generation');

            break;
    }
}

main(); 