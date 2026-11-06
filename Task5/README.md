### How to check:
#### 1.
```shell
kubectl run test-$RANDOM --rm -it --image=alpine --labels role=front-end -- sh

wget -qO- --timeout=2 http://back-end-api-app
wget -qO- --timeout=2 http://admin-back-end-api-app
wget -qO- --timeout=2 http://admin-front-end-app
```

First `wget` should return:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
To engage with the community please visit
<a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
For enterprise grade support, professional services, additional 
security features and capabilities please refer to
<a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
Others should fail with:
```shell
wget: can't connect to remote host (192.168.194.153): Connection refused
wget: can't connect to remote host (192.168.194.237): Connection refused
```


#### 2.
```shell
kubectl run test-$RANDOM --rm -it --image=alpine --labels role=back-end-api -- sh

wget -qO- --timeout=2 http://front-end-app
wget -qO- --timeout=2 http://admin-back-end-api-app
wget -qO- --timeout=2 http://admin-front-end-app
```
First `wget` should return:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
To engage with the community please visit
<a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
For enterprise grade support, professional services, additional 
security features and capabilities please refer to
<a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```
Others should fail with:
```shell
wget: can't connect to remote host (192.168.194.153): Connection refused
wget: can't connect to remote host (192.168.194.237): Connection refused
```


#### 3.
```shell
kubectl run test-$RANDOM --rm -it --image=alpine --labels role=admin-front-end -- sh

wget -qO- --timeout=2 http://front-end-app
wget -qO- --timeout=2 http://back-end-api-app
wget -qO- --timeout=2 http://admin-back-end-api-app
```
First two should fail with:
```shell
wget: can't connect to remote host (192.168.194.207): Connection refused
wget: can't connect to remote host (192.168.194.240): Connection refused
```
Last `wget` should return:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
To engage with the community please visit
<a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
For enterprise grade support, professional services, additional 
security features and capabilities please refer to
<a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```


#### 4.
```shell
kubectl run test-$RANDOM --rm -it --image=alpine --labels role=admin-back-end-api -- sh

wget -qO- --timeout=2 http://front-end-app
wget -qO- --timeout=2 http://back-end-api-app
wget -qO- --timeout=2 http://admin-front-end-app
```
First two should fail with:
```shell
wget: can't connect to remote host (192.168.194.207): Connection refused
wget: can't connect to remote host (192.168.194.240): Connection refused
```
Last `wget` should return:
```html
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
html { color-scheme: light dark; }
body { width: 35em; margin: 0 auto;
font-family: Tahoma, Verdana, Arial, sans-serif; }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, nginx is successfully installed and working.
Further configuration is required for the web server, reverse proxy, 
API gateway, load balancer, content cache, or other features.</p>

<p>For online documentation and support please refer to
<a href="https://nginx.org/">nginx.org</a>.<br/>
To engage with the community please visit
<a href="https://community.nginx.org/">community.nginx.org</a>.<br/>
For enterprise grade support, professional services, additional 
security features and capabilities please refer to
<a href="https://f5.com/nginx">f5.com/nginx</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>
```


#### 5.
```shell
kubectl run test-$RANDOM --rm -it --image=alpine -- sh

wget -qO- --timeout=2 http://front-end-app
wget -qO- --timeout=2 http://back-end-api-app
wget -qO- --timeout=2 http://admin-front-end-app
wget -qO- --timeout=2 http://admin-back-end-api-app
```
All should fail with:
```shell
/ # wget -qO- --timeout=2 http://front-end-app
wget: can't connect to remote host (192.168.194.207): Connection refused
/ # wget -qO- --timeout=2 http://back-end-api-app
wget: can't connect to remote host (192.168.194.240): Connection refused
/ # wget -qO- --timeout=2 http://admin-front-end-app
wget: can't connect to remote host (192.168.194.237): Connection refused
/ # wget -qO- --timeout=2 http://admin-back-end-api-app
wget: can't connect to remote host (192.168.194.153): Connection refused
```
