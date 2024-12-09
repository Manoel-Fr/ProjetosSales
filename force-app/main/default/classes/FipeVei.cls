public with sharing class FipeVei {
    public static List<Object> getCars(string cod) {
        String url = 'https://brasilapi.com.br/api/fipe/preco/v1/'+cod;

HttpRequest req = new HttpRequest();
req.setEndpoint(url);
req.setMethod('GET');

Http http = new Http();
HTTPResponse res = http.send(req);

if(res.getStatusCode() == 200) {
List<Object> result = (List<Object>) JSON.deserializeUntyped(res.getBody());

      return result;
 } else {
   return null;

   }
     

    }
}