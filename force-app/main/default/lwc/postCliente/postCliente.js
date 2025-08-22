import { LightningElement, api, track } from 'lwc';
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import enviarParaAPI from '@salesforce/apex/PostClientes.enviarParaAPI';

export default class postCliente extends LightningElement {

    @api recordId;
    @track fraseEfeito = 'Esta ação não poderá ser desfeita!';
    @track msg = '';
    @track showLog = false;
    @track showSpinner = false;

    async runJs(){

        this.showSpinner = true;
        this.showLog = false;
        this.fraseEfeito = 'Esse processo pode demorar um pouco! Por Favor, aguarde!';

        await enviarParaAPI({
            recordId : this.recordId
        }).then(result => {

            if(result.status === 'erro'){
                this.showLog = true;
                this.msg = result.mensagem;
 
                console.log(result);
                this.fraseEfeito = 'Revise os erros!';
                return;
            }

            this.closeAction();
            this.showToast('Sucesso', 'success', 'Cliente enviado com Sucesso!');
            
        }).catch(err =>{
            console.log(err);
            this.fraseEfeito = 'Erro! Comunique a equipe de TI!';

            this.msg = JSON.stringify(err, null, 2);
            this.showLog = true;
        });

        this.showSpinner = false;


    }

    showToast(title, variant, message){
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            });
        this.dispatchEvent(evt);
    }

    closeAction() {
        const closeModalEvent = new CustomEvent("modalclose");
        this.dispatchEvent(closeModalEvent);
      }


}