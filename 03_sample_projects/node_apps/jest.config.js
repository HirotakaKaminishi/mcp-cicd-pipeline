module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/__tests__/**/*.js', '**/?(*.)+(spec|test).js'],
  collectCoverage: true,
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/**/*.test.js'
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  // Fix Jest hanging on completion
  forceExit: true,
  detectOpenHandles: false,
  testTimeout: 10000,
  setupFilesAfterEnv: ['<rootDir>/jest.setup.js']
};