import { LightningElement,track, api } from 'lwc';
import  pegarMoedas from '@salesforce/apex/buscaMoedas.pegarMoedas';
import  busDias from '@salesforce/apex/UltimosDias.busDias';
import  saveQuo from '@salesforce/apex/UltimosDias.saveQuo';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class GetMoedas extends LightningElement {
    @track moedas;
    @track error;
    @track selecionarMoedas = '';
    @track valueMoeda = 0;
    @track columns; 
    @track data = [];
    @track isloading = false;
    @track selecionarData = 7;
    @track pesquisa;
    @track moeda;
    @track Data;
    @track cotacao;
    @api recordId;
    @track bidHj;
    @track bidAnt;
    @track vari;
   
    columns= [
        {label: 'Moeda' ,fieldName: 'code',  type:'text', cellAttributes: { alignment: 'center'}},
        {label: 'Cotação' ,fieldName: 'bid',  type:'currency', cellAttributes: { alignment: 'center'}},
        {label: 'Variação' ,fieldName: 'pctChange',  type:'percent',  cellAttributes: { alignment: 'center'}},
        {label: 'Data' ,fieldName: 'create_date',  type:'date',  cellAttributes: { alignment: 'center'}}
       
        
   

    ];

    get options() {
        return [
            { label: 'USD', value: 'USD'  },
            { label: 'EURO', value: 'EUR' },
            { label: 'BTC', value:  'BTC' },
        ];
    }
  pesquisa = [
   
            {fieldName: 'code' ,  type:'text'},
            {fieldName: 'create_date' ,  type:'date' }
        
        ];
  
     @track history = [];

  

    handleChange(event) {
        this.selecionarMoedas = event.detail.value;
        this.getMoeda();
        this.getDias();    
    
    } 
  
    async getMoeda() {
        this.isloading = true;
      try {
        let result = await pegarMoedas();
        this.moedas = result;
        this.valueMoeda = result[this.selecionarMoedas];
        this.getHistorico();
       
        
       
  
        this.error = undefined;
      } catch (error){
        this.error = error;
        this.moedas = undefined;
    }     this.isloading = false;
}


    async getDias () {
        this.isloading = true;
        try{ 
            let result = await busDias({moeda: this.selecionarMoedas, numeroDias: this.selecionarData});
            let createDate = new Date(result[0].create_date);
        

            result.forEach(element => {
                if(element.create_date != undefined){
                    return;
                }
                createDate.setDate(createDate.getDate() - 1)
               
                element.create_date = new Date(createDate);

                element.code = this.selecionarMoedas;

      
                let anterior = element.filter((el,index) => {
                    return index > 0 && el.create_date < element[index - 1].create_date;
                } )

                let bidAnt = anterior[0].bid;
                let bidHj = element[element.length - 1].bid

                let vari = ((bidHj - bidAnt) / bidAnt) * 100;
                 
                  element.pctChange = vari ;
               
              
            });


     /*    for(let i = element.bid; i < element.length ; i++){
                let vari = ((element[i].bid - element[i - 1].bid) / element[i - 1].bid) * 100;
                    
                     element.pctChange = (vari);
                } */

     
           
            this.data = result; 
            console.log(this.data);
           
            this.error = undefined;
        } catch (error) {
            this.error = error;
            this.data = [];
         }  this.isloading = false;
     
     }  



    

   

      getHistorico () {
        
        const entrada = {
            code: this.selecionarMoedas,
            create_date: new Date()
        } 
         this.history = [entrada,...this.history]
        
        if(this.history.length > 10 ){
          this.history.pop()
        };
        
     };


       
     handleAmountChange(e){
        this.selecionarData = e.detail.value;
        this.getDias();
      
     }

 async saveCoin(){
  try{
     await saveQuo ({result : this.data});

     const event = new ShowToastEvent({
        title: 'Sucesso',
        message: 'Cotações salvas com sucesso!',
        variant: 'success',
    });
    this.dispatchEvent(event);

  } catch (error){
    this.error = error;
  }
 }


    connectedCallback () {
        this.getMoeda();
        this.getDias();
      
 
    };
} 
     

