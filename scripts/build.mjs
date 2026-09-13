import { build } from 'esbuild';
await build({entryPoints:['src/app.js'],bundle:true,format:'esm',platform:'browser',target:['es2022'],outfile:'dist/app.js',minify:true,legalComments:'eof'});
console.log('Arkham webapp built.');
