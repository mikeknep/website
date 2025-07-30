# mikeknep.com

My personal website.


```
docker build . --tag mikeknep-website-dev:latest
docker run --rm -it -p 4000:4000 -v $(pwd):/app mikeknep-website-dev:latest
```
