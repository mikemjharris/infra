// CloudFront Function on viewer requests:
//  - the alternate hostnames (e.g. the apex) get a 301 to the canonical one;
//    anything else, such as the *.cloudfront.net test address, is served;
//  - "/dir" (no file extension) gets a 301 to "/dir/", as nginx did, so
//    relative links inside the folder keep working;
//  - "/dir/" is served from "/dir/index.html".
var REDIRECT_HOSTS = ${redirect_hosts};

function queryString(querystring) {
  var query = Object.keys(querystring)
    .map(function (k) {
      var q = querystring[k];
      return q.multiValue
        ? q.multiValue.map(function (v) { return k + '=' + v.value; }).join('&')
        : k + '=' + q.value;
    })
    .join('&');
  return query ? '?' + query : '';
}

function redirect(location) {
  return {
    statusCode: 301,
    statusDescription: 'Moved Permanently',
    headers: { location: { value: location } },
  };
}

function handler(event) {
  var request = event.request;
  var host = request.headers.host ? request.headers.host.value : '';

  if (REDIRECT_HOSTS.indexOf(host) !== -1) {
    return redirect('https://${canonical_host}' + request.uri + queryString(request.querystring));
  }

  var lastSegment = request.uri.split('/').pop();
  if (lastSegment !== '' && lastSegment.indexOf('.') === -1) {
    return redirect(request.uri + '/' + queryString(request.querystring));
  }

  if (request.uri.endsWith('/')) {
    request.uri += 'index.html';
  }
  return request;
}
