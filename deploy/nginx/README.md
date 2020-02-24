## nginx setup

* install nginx
* include `pte.conf` full path in your nginx.conf file
* edit `pte.conf` to change pathes.
* download `mkcert` from https://github.com/FiloSottile/mkcert/releases to a PATH folder
* go to `cert` folder:

```
cd deploy/nginx/cert
```bash
* install a trusted certificate:
```

```bash
mkcert --install
mkcert "*.english-learning.ir"
```

* edit `/etc/hosts` file and add the following:

```
127.0.0.1 pte.english-learning.ir
```

* restart your browser
* start nginx
