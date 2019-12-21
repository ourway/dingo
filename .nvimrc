:nnoremap <F8> :silent !./node_modules/prettier/bin-prettier.js  --parser babylon --no-semi --write --single-quote % <CR><CR>
:nnoremap <leader>f :silent !.env/bin/autopep8 -i -a -a -a % <CR><CR>
