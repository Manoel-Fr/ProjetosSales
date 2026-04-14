import boto3    
  import base64
  import json
  import os
  import logging
  import re                                                                                                                                                           
   
  logger = logging.getLogger()                                                                                                                                        
  logger.setLevel(logging.INFO)

  MODELO = os.environ.get('MODELO', 'anthropic.claude-3-haiku-20240307-v1:0')                                                                                         
  REGIAO = os.environ.get('REGIAO', 'us-east-1')
                                                                                                                                                                      
  bedrock = boto3.client('bedrock-runtime', region_name=REGIAO)                                                                                                       
   
  PROMPT = """Analise este documento e extraia as informações abaixo.                                                                                                 
  Retorne APENAS um JSON válido, sem texto adicional, no formato:
                                                                                                                                                                      
  {               
    "titulo": "título ou assunto principal do documento",
    "data_relatorio": "data no formato YYYY-MM-DD ou null",                                                                                                           
    "periodo": "período de referência ex: Janeiro/2025 ou null",                                                                                                      
    "responsavel": "nome do responsável, autor ou emissor ou null",                                                                                                   
    "valor_total": "valor numérico principal sem símbolo de moeda ou null",                                                                                           
    "resumo": "resumo em até 2 frases do conteúdo"                                                                                                                    
  }                                                                                                                                                                   
                                                                                                                                                                      
  Se não encontrar um campo, use null."""                                                                                                                             
                  

  def lambda_handler(event, context):
      try:
          body = json.loads(event.get('body', '{}'))                                                                                                                  
      except Exception:
          return resposta(400, {'erro': 'Body inválido'})                                                                                                             
                                                                                                                                                                      
      doc_base64 = body.get('documento')
      extensao   = body.get('extensao', 'pdf').lower()                                                                                                                
      case_id    = body.get('caseId')                                                                                                                                 
   
      if not doc_base64 or not case_id:                                                                                                                               
          return resposta(400, {'erro': 'Campos obrigatórios: documento, caseId'})
                                                                                                                                                                      
      media_type = resolver_media_type(extensao)
      if not media_type:                                                                                                                                              
          return resposta(400, {'erro': f'Formato não suportado: {extensao}'})                                                                                        
   
      # Monta o conteúdo da mensagem conforme o tipo                                                                                                                  
      if media_type == 'application/pdf':
          content = [                                                                                                                                                 
              {   
                  "type": "document",
                  "source": {
                      "type": "base64",
                      "media_type": "application/pdf",
                      "data": doc_base64
                  }                                                                                                                                                   
              },
              {"type": "text", "text": PROMPT}                                                                                                                        
          ]       
      else:
          content = [
              {
                  "type": "image",
                  "source": {
                      "type": "base64",
                      "media_type": media_type,                                                                                                                       
                      "data": doc_base64
                  }                                                                                                                                                   
              },  
              {"type": "text", "text": PROMPT}
          ]

      try:
          response = bedrock.invoke_model(
              modelId=MODELO,                                                                                                                                         
              body=json.dumps({
                  "anthropic_version": "bedrock-2023-05-31",                                                                                                          
                  "max_tokens": 1024,
                  "messages": [{"role": "user", "content": content}]
              })                                                                                                                                                      
          )
      except Exception as e:                                                                                                                                          
          logger.error(f"Erro ao chamar Bedrock: {e}")
          return resposta(500, {'erro': f'Erro ao chamar IA: {str(e)}'})
                                                                                                                                                                      
      resultado = json.loads(response['body'].read())
      texto = resultado['content'][0]['text']                                                                                                                         
      logger.info(f"Resposta Claude: {texto}")                                                                                                                        
   
      dados = extrair_json(texto)                                                                                                                                     
      return resposta(200, dados)
                                                                                                                                                                      
   
  def extrair_json(texto):                                                                                                                                            
      # Tenta parsear direto
      try:
          return json.loads(texto)
      except Exception:
          pass                                                                                                                                                        
   
      # Tenta extrair bloco ```json ... ```                                                                                                                           
      match = re.search(r'```(?:json)?\s*([\s\S]*?)```', texto)
      if match:                                                                                                                                                       
          try:
              return json.loads(match.group(1))                                                                                                                       
          except Exception:
              pass

      # Tenta extrair { ... }                                                                                                                                         
      match = re.search(r'\{[\s\S]*\}', texto)
      if match:                                                                                                                                                       
          try:    
              return json.loads(match.group(0))
          except Exception:
              pass                                                                                                                                                    
   
      return {'erro': 'Não foi possível extrair JSON', '_raw': texto}                                                                                                 
                  

  def resolver_media_type(extensao):
      mapa = {
          'pdf':  'application/pdf',                                                                                                                                  
          'png':  'image/png',
          'jpg':  'image/jpeg',                                                                                                                                       
          'jpeg': 'image/jpeg',
          'webp': 'image/webp',
          'gif':  'image/gif',                                                                                                                                        
      }
      return mapa.get(extensao)                                                                                                                                       
                  
                                                                                                                                                                      
  def resposta(status_code, corpo):
      return {                                                                                                                                                        
          'statusCode': status_code,
          'headers': {'Content-Type': 'application/json'},
          'body': json.dumps(corpo, ensure_ascii=False)
      }