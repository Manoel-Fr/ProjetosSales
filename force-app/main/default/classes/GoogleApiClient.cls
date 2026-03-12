/**
 * Cliente HTTP compartilhado pelas classes de integração Google.
 * Centraliza sendRequest e toInt para evitar duplicação.
 */
public with sharing class GoogleApiClient {

    public static HttpResponse sendRequest(
        String endpoint,
        String method,
        String token,
        String contentType,
        String body
    ) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method);
        if (token != null) req.setHeader('Authorization', 'Bearer ' + token);
        if (contentType != null) req.setHeader('Content-Type', contentType);
        if (body != null) req.setBody(body);

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            throw new GoogleDocsException(res.getBody());
        }
        return res;
    }

    public static Integer toInt(Object o) {
        if (o == null) return null;
        if (o instanceof Integer) return (Integer) o;
        if (o instanceof Decimal) return ((Decimal) o).intValue();
        if (o instanceof Double) return ((Double) o).intValue();
        return Integer.valueOf(String.valueOf(o));
    }
}
