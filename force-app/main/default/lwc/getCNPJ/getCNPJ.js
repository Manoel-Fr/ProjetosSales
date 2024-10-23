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
 


     async buscar() {
          
        try {
         
            if(this.input){
            let result = await getInfo({pesquisa: this.input})
            this.result = result?.content || [];

            console.log('resultado', this.result )
        
            }
            

        } catch (error) {
            this.error = error;
        }
    
    } 
      navigateToNewLead(Empresa) {
    
        const defaultValues = encodeDefaultFieldValues ({
            Company: Empresa.razao_social,
            Phone: Empresa.ddd_1 +'-'+ Empresa.telefone_1,
            Email: Empresa.email,
            AnnualRevenue: "",
            NumberOfEmployees:  "" ,
            Street: Empresa.logradouro,
            City: Empresa.municipio,
            PostalCode: Empresa.cep,
            State: Empresa.uf,
            Fax: Empresa.ddd_fax +'-'+ Empresa.num_fax,
           
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

      navigateToNewAccount(Empresa){
        
        const defaultValues = encodeDefaultFieldValues({
            Name: Empresa.razao_social,
            Phone: Empresa.ddd_1 +'-'+ Empresa.telefone_1,
            Fax: Empresa.ddd_fax +'-'+ Empresa.num_fax,
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


      handleSelect(event){
           this.selectMenu = event.detail.value
           let Empresa = this.result.find(item =>  item.cnpj   === event.target.dataset.company);     

        if(this.selectMenu == 'MenuLead'){
            this.navigateToNewLead(Empresa);
        } else if(this.selectMenu == 'MenuConta'){
            this.navigateToNewAccount(Empresa);
        }
      }
    


    connectedCallback () {
        this.buscar();
     
    };

}
