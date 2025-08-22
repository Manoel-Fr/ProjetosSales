public with sharing class PostClientes {
    
    // Endpoint da API
    private static final String API_ENDPOINT = 'https://52d349d9b1fd.ngrok-free.app/contas/importar-sale';
    
    @AuraEnabled
    public static Map<String, Object> enviarParaAPI(String recordId) {
        try {

            
            Account conta = buscarConta(recordId);
            System.debug('Conta encontrada: ' + conta);
            
            String jsonBody = montarJsonConta(conta);
            System.debug('JSON montado: ' + jsonBody);
            
            // Envia para a API
            return fazerRequisicao(jsonBody);
            
        } catch (Exception e) {
            System.debug('Erro geral: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            Map<String, Object> erro = new Map<String, Object>{
                'status' => 'erro',
                'mensagem' => 'Erro ao enviar conta: ' + e.getMessage()
            };
            return erro;
        }
    }
    
    private static Account buscarConta(String recordId) {
        try {
            Account conta = [
                SELECT Id, Name, Phone, Website, Industry
                FROM Account
                WHERE Id = :recordId
                LIMIT 1
            ];
            
            if (conta == null) {
                throw new AuraHandledException('Conta não encontrada');
            }
            
            return conta;
        } catch (Exception e) {
            System.debug('Erro ao buscar conta: ' + e.getMessage());
            throw e;
        }
    }
    
    private static String montarJsonConta(Account conta) {
        try {
            // Tratamento para campos nulos
            List<Map<String, String>> contasJson = new List<Map<String, String>>();
            
            Map<String, String> contaMap = new Map<String, String>{
                'name' => conta.Name != null ? conta.Name : '',
                'phone' => conta.Phone != null ? conta.Phone : '',
                'website' => conta.Website != null ? conta.Website : '',
                'industry' => conta.Industry != null ? conta.Industry : ''
            };
            
            contasJson.add(contaMap);
            
            String jsonString = JSON.serialize(contasJson);
            System.debug('JSON gerado: ' + jsonString);
            return jsonString;
            
        } catch (Exception e) {
            System.debug('Erro ao montar JSON: ' + e.getMessage());
            throw e;
        }
    }
    
    private static Map<String, Object> fazerRequisicao(String jsonBody) {
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        try {
            // Log da configuração da requisição
            System.debug('Configurando requisição para: ' + API_ENDPOINT);
            
            // Configura a requisição
            request.setEndpoint(API_ENDPOINT);
            request.setMethod('POST');
            request.setHeader('Content-Type', 'application/json');
            request.setTimeout(120000); // 2 minutos
            request.setBody(jsonBody);
            
      
            HttpResponse response = http.send(request);
            
          
            System.debug('Status code: ' + response.getStatusCode());
            System.debug('Status: ' + response.getStatus());
            System.debug('Response body: ' + response.getBody());
            
            Integer statusCode = response.getStatusCode();
         
            if (statusCode != 200 && statusCode != 201) {
                return new Map<String, Object>{
                    'status' => 'erro',
                    'mensagem' => 'Erro na API. Status: ' + statusCode + '. Response: ' + response.getBody()
                };
            }
            
         
            String responseBody = response.getBody();
            if (String.isBlank(responseBody)) {
                return new Map<String, Object>{
                    'status' => 'erro',
                    'mensagem' => 'A API retornou uma resposta vazia.'
                };
            }
            
            try {
                return (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            } catch (Exception e) {
                System.debug('Erro ao deserializar resposta: ' + e.getMessage());
                System.debug('Resposta recebida: ' + responseBody);
                return new Map<String, Object>{
                    'status' => 'erro',
                    'mensagem' => 'Erro ao processar resposta da API: ' + e.getMessage()
                };
            }
        } catch (Exception e) {
       
            return new Map<String, Object>{
                'status' => 'erro',
                'mensagem' => 'Erro ao conectar com a API: ' + e.getMessage()
            };
        }
    }
}