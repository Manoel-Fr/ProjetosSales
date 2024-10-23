public with sharing class BuscaCnpj {

  @AuraEnabled

  public static Map<String,object> getInfo (String pesquisa) {
    
  pesquisa = pesquisa.toUpperCase();

   
  String likepesq = '\'%' + pesquisa + '%\''; 

  String query = 'SELECT cnpj, razao_social , nome_fantasia , municipio, uf, email , telefone_1 , logradouro , cep , ddd_fax , ddd_1 , num_fax FROM cnpj WHERE cnpj LIKE '+ likepesq +' OR razao_social LIKE '+ likepesq +' OR nome_fantasia LIKE '+ likepesq +' LIMIT 100 OFFSET 0';
   

   string url = 'https://nitleads-new.datago.com.br/api';  
     
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


