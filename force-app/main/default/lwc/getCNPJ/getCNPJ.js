import { LightningElement, track } from 'lwc';
import getInfo from '@salesforce/apex/BuscaCnpj.getInfo';

export default class GetCNPJ extends LightningElement {
    @track input = '';
    @track error;
    @track result;
  

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
    connectedCallback () {
        this.buscar();
     
 
    };

}
