import { LightningElement, api, wire } from 'lwc';
import getDocumentos from '@salesforce/apex/ControllerDocumento.getDocumentos';
import deleteDocumento from '@salesforce/apex/ControllerDocumento.deleteDocumento';
import setCategoria from '@salesforce/apex/ControllerDocumento.setCategoria';
import getCategoriasPicklist from '@salesforce/apex/ControllerDocumento.getCategoriasPicklist';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';



export default class GerenciarDocumentos extends NavigationMixin(LightningElement) {
    @api recordId;
    files;
    error;
    categoriasPicklist = []; // carregado via @wire
    loading = false;
    isModalOpen = false;
    fileToDelete = null;
    selectedFiles = new Set();
    categoriaSelecionada = 'Diversos';
    categoriaFiltro = ''; // '' = todos, ou valor da categoria para filtrar

    acceptedFormats = ['.pdf', '.doc', '.docx', '.jpg', '.png', '.xls', '.xlsx', '.txt', '.zip', '.csv', '.ppt', '.pptx', '.gif', '.mp4', '.mov', '.avi'];

    @wire(getCategoriasPicklist)
    wiredCategorias({ data, error }) {
        if (data) {
            this.categoriasPicklist = data.map(val => ({ label: val, value: val }));
        }
    
    }

    /** Array de categorias para combobox e navegação */
    get categorias() {
        return this.categoriasPicklist || [];
    }

    /** Categorias para navegação (cards), incluindo "Todos" */
    get categoriasNav() {
        const filtro = this.categoriaFiltro;
        return [
            { label: 'Todos', value: '', key: 'todos', navCardClass: !filtro ? 'nav-card nav-card-ativo' : 'nav-card' },
            ...this.categorias.map(c => ({
                ...c,
                key: c.value,
                navCardClass: filtro === c.value ? 'nav-card nav-card-ativo' : 'nav-card'
            }))
        ];
    }

   
    get filesFiltrados() {
        if (!this.files) return [];
        if (!this.categoriaFiltro) return this.files;
        return this.files.filter(f => f.categoria === this.categoriaFiltro);
    }

    get isCategoriaVazia() {
        return !this.categoriaSelecionada;
    }

    @api
    validarDocumentos() {
        const faltando = this.categoriasFaltando;
        if (faltando.length > 0) {
            return {
                isValid: false,
                errors: faltando.map(cat => `Obrigatório pelo menos um anexo da categoria: ${cat}`)
            };
        }
        return { isValid: true, errors: [] };
    }

    connectedCallback() {
        this.carregarArquivos();
    }

    carregarArquivos() {
        if (!this.recordId) return;

        getDocumentos({ accId: this.recordId })
            .then(result => {
                this.files = result.map(doc => this.mapDocumento(doc));
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.files = [];
            });
    }

    mapDocumento(doc) {
        const isImage = ['png', 'jpg', 'jpeg', 'gif'].includes(doc.FileExtension?.toLowerCase());
        const contentVersionId = doc.ContentVersionId ?? null;
        const categoria = doc.categoria || 'Diversos';
        const categoriaBadgeClass = this.mapCategoriaBadgeClass(categoria);

        return {
            ...doc,
            isImage,
            ContentVersionId: contentVersionId,
            iconName: this.mapIcon(doc.FileExtension),
            previewUrl: isImage && contentVersionId
                ? `/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=${contentVersionId}`
                : null,
            downloadUrl: contentVersionId
                ? `/sfc/servlet.shepherd/version/download/${contentVersionId}`
                : null,
            formattedDate: this.formatDate(doc.CreatedDate),
            formattedSize: this.formatFileSize(doc.ContentSize),
            categoria,
            categoriaBadgeClass
        };
    }

    mapCategoriaBadgeClass(categoria) {
        if (categoria === 'Etiqueta do Produto') return 'categoria-badge categoria-badge--etiqueta';
        if (categoria === 'Vídeo e/ou Foto do Problema') return 'categoria-badge categoria-badge--video';
        return 'categoria-badge';
    }

    handleCategoriaChange(event) {
        this.categoriaSelecionada = event.detail.value;
    }

    handleNavCardClick(event) {
        const categoria = event.currentTarget.dataset.categoria;
        this.categoriaFiltro = categoria || '';
    }

    formatDate(dateString) {
        if (!dateString) return '';

        const date = new Date(dateString);
        if (isNaN(date.getTime())) return dateString;

        return date.toLocaleDateString('pt-BR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric'
        });
    }

    formatFileSize(tamanho) {
        if (!tamanho || tamanho === 0) return '0 B';

        const tamanhos = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(tamanho) / Math.log(1024));

        if (i === 0) return `${tamanho} B`;

        return `${(tamanho / Math.pow(1024, i)).toFixed()} ${tamanhos[i]}`;
    }

    mapIcon(extension) {
        switch ((extension || '').toLowerCase()) {
            case 'pdf': return 'doctype:pdf';
            case 'xls':
            case 'xlsx': return 'doctype:excel';
            case 'doc':
            case 'docx': return 'doctype:word';
            case 'png':
            case 'jpg':
            case 'jpeg':
            case 'gif': return 'doctype:image';
            case 'txt': return 'doctype:txt';
            case 'zip': return 'doctype:zip';
            case 'mp4':
            case 'mov':
            case 'avi': return 'doctype:video';
            default: return 'doctype:attachment';
        }
    }

    arquivosEnviados(event) {
        const uploadedFiles = event.detail.files;
        const categoria = this.categoriaSelecionada;

        this.loading = true;

        const categoriasPromises = uploadedFiles.map(file => {
            const contentVersionId = file.contentVersionId || file.ContentVersionId;
            return setCategoria({ contentVersionId, categoria });
        });

        Promise.all(categoriasPromises)
            .then(() => {
                return getDocumentos({ accId: this.recordId });
            })
            .then(result => {
                this.files = result.map(doc => this.mapDocumento(doc));
                this.loading = false;
                this.showToast('Sucesso', 'Arquivo(s) enviado(s) com sucesso', 'success');
            })
            .catch(error => {
                const msg = error?.body?.message || error?.message || 'Erro ao enviar arquivo(s)';
                this.showToast('Erro', msg, 'error');
                this.loading = false;
                this.carregarArquivos();
            });
    }

    handleMenuSelect(event) {
        const selectedValue = event.detail.value;
        const fileId = event.target.dataset.fileId;
        const file = this.files.find(f => f.Id === fileId);

        if (!file) return;

        switch (selectedValue) {
            case 'preview':
                this.handlePreview(file);
                break;
            case 'download':
                this.handleDownload(file);
                break;
            case 'edit':
                this.handleEdit(file);
                break;
            case 'delete':
                this.handleDelete(file);
                break;
        }
    }

    handlePreview(eventOrFile) {
        let file;

        if (eventOrFile.target && eventOrFile.target.dataset) {
            eventOrFile.preventDefault();
            const fileId = eventOrFile.target.dataset.fileId;
            file = this.files.find(f => f.Id === fileId);
        } else {
            file = eventOrFile;
        }

        if (!file) return;

        try {
            if (file.isImage && file.previewUrl) {
                window.open(file.previewUrl, '_blank');
                return;
            }

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: file.Id,
                    objectApiName: 'ContentDocument',
                    actionName: 'view'
                }
            });

        } catch (error) {
            console.error('Erro ao visualizar arquivo:', error);

            if (file.downloadUrl) {
                window.open(file.downloadUrl, '_blank');
            } else {
                this.showToast('Erro', 'Não foi possível visualizar o arquivo', 'error');
            }
        }
    }

    handleDownload(file) {
        try {
            if (file.downloadUrl) {
                window.open(file.downloadUrl, '_blank');
            } else {
                this.showToast('Erro', 'Não foi possível fazer o download do arquivo', 'error');
            }
        } catch (error) {
            this.showToast('Erro', 'Não foi possível fazer o download do arquivo', 'error');
        }
    }

    handleEdit(file) {
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: file.Id,
                    objectApiName: 'ContentDocument',
                    actionName: 'edit'
                }
            });
        } catch (error) {
            console.error('Erro ao editar arquivo:', error);
            this.showToast('Erro', 'Não foi possível abrir o arquivo para edição', 'error');
        }
    }

    hideModalBox() {
        this.isModalOpen = false;
        this.fileToDelete = null;
    }

    handleDelete(file) {
        this.fileToDelete = file;
        this.isModalOpen = true;
    }

    confirmarExclusao() {
        if (!this.fileToDelete) {
            this.hideModalBox();
            return;
        }

        this.loading = true;

        deleteDocumento({ documentId: this.fileToDelete.Id })
            .then(result => {
                if (result === 'success') {
                    this.showToast('Sucesso', 'Arquivo excluído com sucesso', 'success');
                    this.carregarArquivos();
                } else {
                    this.showToast('Erro', result, 'error');
                }
            })
            .catch(() => {
                this.showToast('Erro', 'Não foi possível excluir o arquivo', 'error');
            })
            .finally(() => {
                this.loading = false;
                this.hideModalBox();
            });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(evt);
    }

    handleLinkClick(event) {
        event.preventDefault();
        const url = event.currentTarget.href;

        if (url) {
            window.open(url, '_blank');
        }
    }
}
