import { LightningElement, api, track } from 'lwc';
import getFileInfo   from '@salesforce/apex/PhotoController.getFileInfo';                                                             
import generatePDF   from '@salesforce/apex/PhotoController.generatePDF';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';                                                                         
                
const MAX_PHOTOS = 5;                                                                                                                      
                
export default class PhotoOrderPDF extends LightningElement {

    @api   recordId;
    @track photos       = [];
    @track isGenerating = false;

    // chamado quando o upload termina                                                                                                     
    handleUpload(event) {
        const uploadedFiles = event.detail.files;                                                                                          
                                                                                                                                           
        if (this.photos.length + uploadedFiles.length > MAX_PHOTOS) {
            this.showToast('Atenção', `Máximo de ${MAX_PHOTOS} fotos permitido.`, 'warning');                                              
            return;                                                                                                                        
        }
                                                                                                                                           
        const newIds = uploadedFiles.map(f => f.contentVersionId);                                                                         

        getFileInfo({ contentVersionIds: newIds })                                                                                         
            .then(result => {
                result.forEach(fi => {                                                                                                     
                    this.photos.push({
                        id:         fi.id,
                        title:      fi.title,
                        previewUrl: fi.previewUrl
                    });                                                                                                                    
                });
                this.refreshPositions();                                                                                                   
            })  
            .catch(error => {
                this.showToast('Erro', error.body.message, 'error');
            });                                                                                                                            
    }
                                                                                                                                           
    moveUp(event) {
        const id    = event.currentTarget.dataset.id;
        const index = this.photos.findIndex(p => p.id === id);                                                                             
        if (index <= 0) return;
                                                                                                                                           
        const arr = [...this.photos];
        [arr[index - 1], arr[index]] = [arr[index], arr[index - 1]];
        this.photos = arr;                                                                                                                 
        this.refreshPositions();
    }                                                                                                                                      
                
    moveDown(event) {
        const id    = event.currentTarget.dataset.id;
        const index = this.photos.findIndex(p => p.id === id);                                                                             
        if (index >= this.photos.length - 1) return;
                                                                                                                                           
        const arr = [...this.photos];
        [arr[index + 1], arr[index]] = [arr[index], arr[index + 1]];
        this.photos = arr;                                                                                                                 
        this.refreshPositions();
    }                                                                                                                                      
                
    removePhoto(event) {
        const id    = event.currentTarget.dataset.id;
        this.photos = this.photos.filter(p => p.id !== id);                                                                                
        this.refreshPositions();
    }                                                                                                                                      
                
    handleGeneratePDF() {
        if (!this.recordId) {
            this.showToast('Erro', 'Componente precisa estar em uma página de registro.', 'error');
            return;
        }

        if (this.photos.length === 0) {
            this.showToast('Atenção', 'Adicione ao menos uma foto.', 'warning');
            return;
        }

        this.isGenerating = true;
        const orderedIds  = this.photos.map(p => p.id);

        generatePDF({ orderedIds, recordId: this.recordId })
            .then(() => {
                this.isGenerating = false;
                this.showToast('Sucesso', 'PDF anexado ao registro com sucesso!', 'success');
            })
            .catch(error => {
                this.isGenerating = false;
                this.showToast('Erro ao gerar PDF', error.body.message, 'error');
            });
    }                                                                                                                                      
                
    // recalcula position, isFirst e isLast para os botões                                                                                 
    refreshPositions() {
        this.photos = this.photos.map((p, i) => ({                                                                                         
            ...p,
            position: i + 1,                                                                                                               
            isFirst:  i === 0,
            isLast:   i === this.photos.length - 1                                                                                         
        }));    
    }

    showToast(title, message, variant) {                                                                                                   
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }                                                                                                                                      
}               
