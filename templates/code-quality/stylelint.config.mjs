export default {
  extends: ['stylelint-config-standard'],
  ignoreFiles: [
    'node_modules/**/*',
    'dist/**/*',
    'build/**/*',
    'coverage/**/*',
    '.next/**/*',
    'out/**/*',
  ],
  rules: {
    'at-rule-no-unknown': [
      true,
      {
        ignoreAtRules: [
          'tailwind',
          'apply',
          'layer',
          'config',
          'theme',
          'utility',
          'variant',
          'responsive',
          'screen',
        ],
      },
    ],
  },
};
