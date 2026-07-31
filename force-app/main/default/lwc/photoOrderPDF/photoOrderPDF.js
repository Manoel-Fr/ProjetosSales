import { LightningElement, api, track } from 'lwc';
import getLinkedImageFiles from '@salesforce/apex/PhotoController.getLinkedImageFiles';
import generatePDF from '@salesforce/apex/PhotoController.generatePDF';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PhotoOrderPDF extends LightningElement {
    _recordId;

    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        if (value === this._recordId) {
            return;
        }
        this._recordId = value;
        if (value) {
            this.loadPhotos();
        } else {
            this.photos = [];
        }
    }

    @track photos = [];
    @track isGenerating = false;

    loadPhotos() {
        if (!this._recordId) {
            return Promise.resolve();
        }
        return getLinkedImageFiles({ recordId: this._recordId })
            .then((data) => {
                this.applyRawVersionsToPhotos(data);
            })
            .catch((error) => {
                this.photos = [];
                const msg =
                    error.body && error.body.message
                        ? error.body.message
                        : 'Não foi possível carregar as imagens.';
                this.showToast('Erro', msg, 'error');
            });
    }

    /** Chamado pelo pai após upload/exclusão — sempre vai ao servidor (Apex sem cacheable). */
    @api
    refreshListaFotos() {
        return this.loadPhotos();
    }

    applyRawVersionsToPhotos(data) {
        if (!Array.isArray(data)) {
            return;
        }
        // Apex devolve FileInfo: id, title, categoria, previewUrl (camelCase no LWC)
        this.photos = data.map((row) => {
            const versionId = row.id || row.Id;
            const previewUrl =
                row.previewUrl ||
                (versionId ? '/sfc/servlet.shepherd/version/download/' + versionId : '');
            return {
                id: versionId,
                title: row.title || row.Title || '',
                categoria: row.categoria != null ? row.categoria : row.Categoria || '',
                previewUrl
            };
        });
        this.refreshPositions();
    }

    moveUp(event) {
        const id = event.currentTarget.dataset.id;
        const index = this.photos.findIndex((p) => p.id === id);
        if (index <= 0) return;

        const arr = [...this.photos];
        [arr[index - 1], arr[index]] = [arr[index], arr[index - 1]];
        this.photos = arr;
        this.refreshPositions();
    }

    moveDown(event) {
        const id = event.currentTarget.dataset.id;
        const index = this.photos.findIndex((p) => p.id === id);
        if (index >= this.photos.length - 1) return;

        const arr = [...this.photos];
        [arr[index + 1], arr[index]] = [arr[index], arr[index + 1]];
        this.photos = arr;
        this.refreshPositions();
    }

    removePhoto(event) {
        const id = event.currentTarget.dataset.id;
        this.photos = this.photos.filter((p) => p.id !== id);
        this.refreshPositions();
    }

    handleGeneratePDF() {
        if (!this._recordId) {
            this.showToast('Erro', 'Componente precisa estar em uma página de registro.', 'error');
            return;
        }

        if (this.photos.length === 0) {
            this.showToast('Atenção', 'Adicione ao menos uma foto.', 'warning');
            return;
        }

        this.isGenerating = true;
        const orderedIds = this.photos.map((p) => p.id);

        generatePDF({ orderedIds, recordId: this._recordId })
            .then(() => {
                this.isGenerating = false;
                this.showToast('Sucesso', 'PDF anexado ao registro com sucesso!', 'success');
            })
            .catch((error) => {
                this.isGenerating = false;
                const msg =
                    error.body && error.body.message ? error.body.message : 'Falha ao gerar o PDF.';
                this.showToast('Erro ao gerar PDF', msg, 'error');
            });
    }

    refreshPositions() {
        this.photos = this.photos.map((p, i) => ({
            ...p,
            position: i + 1,
            isFirst: i === 0,
            isLast: i === this.photos.length - 1
        }));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}