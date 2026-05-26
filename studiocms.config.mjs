import { defineStudioCMSConfig } from 'studiocms/config';
import studiocmsHTML from '@studiocms/html';
import studiocmsMD from '@studiocms/md';

export default defineStudioCMSConfig({
  dbStartPage: false,
  db: {
    dialect: 'mysql',
  },
  plugins: [
    studiocmsHTML(),
    studiocmsMD(),
  ],
});