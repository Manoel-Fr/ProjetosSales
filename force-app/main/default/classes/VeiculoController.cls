public with sharing class VeiculoController {
    

    @AuraEnabled()
    public static List<Account> getClientes() {
        try {
            List<Account> clientes = [
                SELECT Id, Name, Phone, Website, Industry
                FROM Account
                // WHERE IsActive = true
            ];
            return clientes;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<VeiculoWrapper> getVeiculos() {
        List<VeiculoWrapper> veiculos = new List<VeiculoWrapper>();
        
        List<Product2> produtos = [
            SELECT 
                Id,
                Name,
                ProductCode,
                Marca__c,
                Modelo__c,
                Ano__c,
                Cor__c,
                Quilometragem__c,
                Preco__c,
                Custo__c,
                Comissao__c,
                Status_Veiculo__c,
                Placa__c,
                Combustivel__c,
                Cambio__c,
                Portas__c,
                UrlMin__c,
                Description
            FROM Product2
            WHERE IsActive = true
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
        
        for (Product2 p : produtos) {
            veiculos.add(new VeiculoWrapper(p));
        }
        
        return veiculos;
    }
    
  
    @AuraEnabled(cacheable=true)
    public static List<VeiculoWrapper> getVeiculosFiltrados(String termoBusca, String marca, String ano) {
        List<VeiculoWrapper> veiculos = new List<VeiculoWrapper>();
        
        String query = 'SELECT Id, Name, ProductCode, Marca__c, Modelo__c, Ano__c, Cor__c, ';
        query += 'Quilometragem__c, Preco__c, Custo__c, Comissao__c, Status_Veiculo__c, Placa__c, Combustivel__c, ';
        query += 'Cambio__c, Portas__c, UrlMin__c, Description ';
        query += 'FROM Product2 WHERE IsActive = true';
        
        // Filtro por termo de busca
        if (String.isNotBlank(termoBusca)) {
            String termo = '%' + termoBusca + '%';
            query += 'AND (Marca__c LIKE :termo OR Modelo__c LIKE :termo OR Name LIKE :termo) ';
        }
        
        // Filtro por marca
        if (String.isNotBlank(marca)) {
            query += 'AND Marca__c = :marca ';
        }
        
        // Filtro por ano
        if (String.isNotBlank(ano)) {
            query += 'AND Ano__c = :ano ';
        }
        
        query += 'ORDER BY CreatedDate DESC LIMIT 100';
        
        List<Product2> produtos = Database.query(query);
        
        for (Product2 p : produtos) {
            veiculos.add(new VeiculoWrapper(p));
        }
        
        return veiculos;
    }
    
 
    @AuraEnabled(cacheable=true)
    public static List<String> getMarcas() {
        List<String> marcas = new List<String>();
        
        AggregateResult[] results = [
            SELECT Marca__c 
            FROM Product2 
            WHERE IsActive = true AND Marca__c != null
            GROUP BY Marca__c
            ORDER BY Marca__c
        ];
        
        for (AggregateResult ar : results) {
            marcas.add((String) ar.get('Marca__c'));
        }
        
        return marcas;
    }
    
 
    @AuraEnabled(cacheable=true)
    public static List<String> getAnos() {
        List<String> anos = new List<String>();
        
        AggregateResult[] results = [
            SELECT Ano__c 
            FROM Product2 
            WHERE IsActive = true AND Ano__c != null
            GROUP BY Ano__c
            ORDER BY Ano__c DESC
        ];
        
        for (AggregateResult ar : results) {
            anos.add((String) ar.get('Ano__c'));
        }
        
        return anos;
    }
 
    public class VeiculoWrapper {
        @AuraEnabled public String Id;
        @AuraEnabled public String nome;
        @AuraEnabled public String codigo;
        @AuraEnabled public String marca;
        @AuraEnabled public String modelo;
        @AuraEnabled public String ano;
        @AuraEnabled public String cor;
        @AuraEnabled public Decimal quilometragem;
        @AuraEnabled public String kmFormatado;
        @AuraEnabled public Decimal preco;
        @AuraEnabled public String precoFormatado;
        @AuraEnabled public Decimal custo;
        @AuraEnabled public String custoFormatado;
        @AuraEnabled public Decimal comissao;
        @AuraEnabled public Decimal lucro;
        @AuraEnabled public String lucroFormatado;
        @AuraEnabled public String status;
        @AuraEnabled public String placa;
        @AuraEnabled public String combustivel;
        @AuraEnabled public String cambio;
        @AuraEnabled public Decimal portas;
        @AuraEnabled public String imagemUrl;
        @AuraEnabled public String descricao;
        
        public VeiculoWrapper(Product2 p) {
            this.Id = p.Id;
            this.nome = p.Name;
            this.codigo = p.ProductCode;
            this.marca = p.Marca__c;
            this.modelo = p.Modelo__c;
            this.ano = p.Ano__c;
            this.cor = p.Cor__c;
            this.quilometragem = p.Quilometragem__c;
            this.kmFormatado = p.Quilometragem__c != null ? 
                String.valueOf(p.Quilometragem__c.format()) + ' km' : '0 km';
            this.preco = p.Preco__c != null ? p.Preco__c : 0;
            this.precoFormatado = p.Preco__c != null ? 
                p.Preco__c.format() : '0,00';
            this.custo = p.Custo__c != null ? p.Custo__c : 0;
            this.custoFormatado = p.Custo__c != null ? 
                p.Custo__c.format() : '0,00';
            this.comissao = p.Comissao__c != null ? p.Comissao__c : 0;
            
            // Calcula o lucro (Preço de Venda - Custo)
            Decimal precoVenda = p.Preco__c != null ? p.Preco__c : 0;
            Decimal custoVeiculo = p.Custo__c != null ? p.Custo__c : 0;
            this.lucro = precoVenda - custoVeiculo;
            this.lucroFormatado = this.lucro.format();
            
            this.status = p.Status_Veiculo__c != null ? p.Status_Veiculo__c : 'Disponível';
            this.placa = p.Placa__c;
            this.combustivel = p.Combustivel__c;
            this.cambio = p.Cambio__c;
            this.portas = p.Portas__c;
            this.imagemUrl = p.UrlMin__c;
            this.descricao = p.Description;
        }
    }
}