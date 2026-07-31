import { LightningElement, track } from 'lwc';
import getInfo from '@salesforce/apex/BuscaCnpj.getInfo';
import { NavigationMixin } from 'lightning/navigation'
import { encodeDefaultFieldValues } from "lightning/pageReferenceUtils";

  export default class GetCNPJ extends NavigationMixin(LightningElement) {
    @track input = '';
    @track error;
    @track result;
    @track selectMenu;
    @track Empresa;
    
  
    handleInputChange(event) {
     
      this.input = event.detail.value;
     
    }
    
    async buscar () {
    
   
      try {
       
        if (this.input) {
         
          let result = await getInfo({
            pesquisa: this.input
          })
        
          this.result = result?.content || [];      
        }
     
  
      } catch (error) {
        this.error = error;

      }
      
  
    }
   

    formatCNPJ(cnpj) {
      if (!cnpj) return '';
      
      return cnpj.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})$/, "$1.$2.$3/$4-$5");
  }

  get formattedResults() {
    return Array.isArray(this.result) ? this.result.map(item => {
        return {
            ...item,
            formattedCNPJ: this.formatCNPJ(item.cnpj)
        };
    }) : []; 
}


    navigateToNewLead(Empresa) {
  
      const completo = Empresa.nome_fantasia.split(' ');
      const first = completo.slice(0, -1).join(' ');
      const last = completo[completo.length - 1];

      const defaultValues = encodeDefaultFieldValues({
        Company: Empresa.razao_social,
        Phone: (Empresa.ddd_1 || '') + ' ' + (Empresa.telefone_1 || ''),
        Email: Empresa.email,
        AnnualRevenue: "",
        NumberOfEmployees: "",
        Street: Empresa.logradouro,
        City: Empresa.municipio,
        PostalCode: Empresa.cep,
        State: Empresa.uf,
        Fax: (Empresa.ddd_fax || '') + ' ' + (Empresa.num_fax || ''),
        FirstName: first,
        LastName: last,
  
      });
  
      this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
          objectApiName: 'Lead',
          actionName: 'new',
        },
        state: {
          defaultFieldValues: defaultValues,
        },
      });
    }
  
    navigateToNewAccount(Empresa) {
  
      const defaultValues = encodeDefaultFieldValues({
        Name: Empresa.razao_social,
        Phone: (Empresa.ddd_1 || '') + ' '+(Empresa.telefone_1 || ''),
        Fax: (Empresa.ddd_fax || '') + ' ' + (Empresa.num_fax || ''),
        BillingStreet: Empresa.logradouro,
        BillingCity: Empresa.municipio,
        BillingPostalCode: Empresa.cep,
        BillingState: Empresa.uf,
  
      });
  
      this[NavigationMixin.Navigate]({
        type: 'standard__objectPage',
        attributes: {
          objectApiName: 'Account',
          actionName: 'new',
        },
        state: {
          defaultFieldValues: defaultValues,
        },
      });
  
    }
  
    handleSelect(event) {
      this.selectMenu = event.detail.value
      let Empresa = this.result.find(item => item.cnpj === event.target.dataset.company);
  
      if (this.selectMenu == 'MenuLead') {
        this.navigateToNewLead(Empresa);
      } else if (this.selectMenu == 'MenuConta') {
        this.navigateToNewAccount(Empresa);
      }
    }

    presENT(event){
      if(event.key==='Enter'){
        this.buscar()
      }
      
      }
    
    connectedCallback() {
      this.buscar();
    };
  
  }