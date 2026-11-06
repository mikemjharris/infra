// CloudFront Function on viewer requests:
//  - the alternate hostnames (e.g. the apex) get a 301 to the canonical one;
//    anything else, such as the *.cloudfront.net test address, is served;
//  - "/dir/" is served from "/dir/index.html", as nginx did.
var REDIRECT_HOSTS = ${redirect_hosts};

function handler(event) {
  var request = event.request;
  var host = request.headers.host ? request.headers.host.value : '';

  if (REDIRECT_HOSTS.indexOf(host) !== -1) {
    var query = Object.keys(request.querystring)
      .map(function (k) {
        var q = request.querystring[k];
        return q.multiValue
          ? q.multiValue.map(function (v) { return k + '=' + v.value; }).join('&')
          : k + '=' + q.value;
      })
      .join('&');
    return {
      statusCode: 301,
      statusDescription: 'Moved Permanently',
      headers: {
        location: { value: 'https://${canonical_host}' + request.uri + (query ? '?' + query : '') },
      },
    };
  }

  if (request.uri.endsWith('/')) {
    request.uri += 'index.html';
  }
  return request;
}
