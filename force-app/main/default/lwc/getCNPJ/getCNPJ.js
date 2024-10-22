import { LightningElement, track } from 'lwc';
import getInfo from '@salesforce/apex/BuscaCnpj.getInfo';
import { NavigationMixin } from 'lightning/navigation'

export default class GetCNPJ extends NavigationMixin(LightningElement) {
    @track input = '';
    @track error;
    @track result;
    @track selectMenu;
  

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


    handleSelect(event){
        this.selectMenu = event.detail.value;

        if(this.selectMenu == 'MenuLead'){

            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Lead',
                    actionName: 'new'
                }
            });
            
        } else if (this.selectMenu == 'MenuConta'){

            this[NavigationMixin.Navigate]({
                type: 'standard__objectPage',
                attributes: {
                    objectApiName: 'Account',
                    actionName: 'new'
                }
            });
        }
        
        
    }



    connectedCallback () {
        this.buscar();
     
    };

}
