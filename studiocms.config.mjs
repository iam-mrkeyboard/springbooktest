import { defineStudioCMSConfig } from 'studiocms/config';
import studiocmsHTML from '@studiocms/html';
import studiocmsMD from '@studiocms/md';
import s3Storage from '@studiocms/s3-storage';

export default defineStudioCMSConfig({
  dbStartPage: false,
  db: {
    dialect: 'mysql',
  },
  storageManager: s3Storage(),
  plugins: [
    studiocmsHTML(),
    studiocmsMD(),
  ],
});