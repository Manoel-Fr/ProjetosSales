public with sharing class BuscaCnpj {

  @AuraEnabled

  public static Map<String,object> getInfo (String pesquisa , String cnpj ) {
    

      
  String formatCnpj = cnpj.replace('.' , '').replace('/', '').replace('-','');
  

 if(cnpj.length() == 18){
      cnpj = formatCnpj;
 }
   
   String query;
   
   pesquisa = '%' + pesquisa + '%';

   query = 'SELECT * FROM cnpj WHERE cnpj = :cnpj OR razao_social LIKE :pesquisa OR nome_fantasia LIKE :pesquisa LIMIT 1 OFFSET 0';
   

   String url = 'https://nitleads-new.datago.com.br/api/getone/'+(String.isNotEmpty(cnpj) ? cnpj : pesquisa); 
   
   HttpRequest req = new HttpRequest(); 
  req.setEndpoint(url);
  req.setMethod('POST');

 String username = 'datago';

 String password = 'jybxXfYcwa1A5WgP4WuOtHqXPfyPGip1';


 Blob headerValor = Blob.valueOf(username + ':' + password);
 String authorizationHeader  = 'basic ' + EncodingUtil.base64Encode (headerValor);
  req.setHeader('Authorization', authorizationHeader );
  req.setHeader('Content-Type', 'application/json');


  string body = '{"query" : "' + query + '"  ,  "token" : "$$$MASTERTOKENnjs498334k6Bw$$$"}';

  req.setBody(body);

  
  Http http = new Http();
  HTTPResponse res = http.send(req);
 
   if(res.getStatusCode()  == 200) {
      
     Map<String,object> result = (Map<String,object>) JSON.deserializeUntyped(res.getBody());
  System.debug(result);

     return result;

   } else {
      return null;
   }

   
  }

}


