import { LightningElement, track } from 'lwc';
import getInfo from '@salesforce/apex/BuscaCnpj.getInfo';

export default class GetCNPJ extends LightningElement {
    @track input = '';
    @track error;
    @track empresa = [];
  

    handleInputChange(event) {
        this.input = event.detail.value;
    }
 


     async buscar() {
        try {
            let result = await getInfo({cnpj: this.input, pesquisa: this.input})
            this.empresa = result || [];

            console.log('resultado', this.empresa )

        } catch(error) {
            this.error = error;
        }

    }
    connectedCallback () {
        this.buscar();
     
 
    };

}
