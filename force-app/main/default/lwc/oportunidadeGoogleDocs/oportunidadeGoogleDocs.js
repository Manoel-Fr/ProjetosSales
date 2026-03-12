import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import isAuthorized from '@salesforce/apex/GoogleAuthService.isAuthorized';
import getAuthorizationUrl from '@salesforce/apex/GoogleAuthService.getAuthorizationUrl';
import createDocumentFromOpportunity from '@salesforce/apex/GoogleDocsService.createDocumentFromOpportunity';
import sendDocumentToAutentique from '@salesforce/apex/AutentiqueService.sendDocumentToAutentique';

const LOADING_MESSAGES_DOCS = [
    'Criando documento...',
    'Copiando modelo...',
    'Substituindo variáveis...',
    'Inserindo tabela de produtos...'
];

const LOADING_MESSAGES_AUTENTIQUE = [
    'Criando documento...',
    'Exportando para PDF...',
    'Enviando ao Autentique...',
    'Quase lá...'
];

export default class OportunidadeGoogleDocs extends LightningElement {
    @api recordId;

    isAuthorized = false;
    isLoading = true;
    loadingMessage = 'Carregando...';
    signerName = '';
    signerEmail = '';
    _progressInterval = null;

    connectedCallback() {
        this.checkAuthorization();
    }

    disconnectedCallback() {
        this.clearProgressInterval();
    }

    get isSendAutentiqueDisabled() {
        return !this.isAuthorized || this.isLoading || !this.signerEmail;
    }

    async checkAuthorization() {
        try {
            await this.withLoading(async () => {
                this.isAuthorized = await isAuthorized();
            });
        } catch (error) {
            console.error('Erro ao verificar autorização:', error);
            this.isAuthorized = false;
        }
    }

    async handleAuthorize() {
        try {
            await this.withLoading(async () => {
                const authorizationUrl = await getAuthorizationUrl({ state: this.recordId });
                this.openInNewTab(authorizationUrl, 'width=600,height=700');
            });

            this.showToast(
                'Autenticação Iniciada',
                'Complete a autenticação na janela que abriu. Após concluir, atualize esta página.',
                'info'
            );
        } catch (error) {
            console.error('Erro ao iniciar autorização:', error);
            this.showError('Não foi possível iniciar a autenticação: ' + this.getErrorMessage(error));
        }
    }

    async handleOpenInDocs() {
        try {
            await this.withLoading(
                async () => {
                    const documentUrl = await createDocumentFromOpportunity({
                        opportunityId: this.recordId
                    });
                    this.openInNewTab(documentUrl);
                },
                LOADING_MESSAGES_DOCS
            );

            this.showToast(
                'Documento Criado!',
                'O documento foi criado no Google Docs e aberto em uma nova aba.',
                'success'
            );
        } catch (error) {
            console.error('Erro ao criar documento:', error);

            const errorMessage = this.getErrorMessage(error);
            if (/refresh token|token/i.test(errorMessage)) {
                this.isAuthorized = false;
                this.showToast(
                    'Autenticação Necessária',
                    'Sua sessão expirou. Por favor, conecte novamente com o Google.',
                    'warning'
                );
            } else {
                this.showError('Não foi possível criar o documento: ' + errorMessage);
            }
        }
    }

    handleSignerNameChange(event) {
        this.signerName = event.target.value;
    }

    handleSignerEmailChange(event) {
        this.signerEmail = event.target.value;
    }

    async handleSendToAutentique() {
        try {
            const result = await this.withLoading(
                () =>
                    sendDocumentToAutentique({
                        opportunityId: this.recordId,
                        signerName: this.signerName,
                        signerEmail: this.signerEmail
                    }),
                LOADING_MESSAGES_AUTENTIQUE
            );

            // if (result?.signatureLink) {
            //     this.openInNewTab(result.signatureLink);
            // } else if (result?.googleDocUrl) {
            //     this.openInNewTab(result.googleDocUrl);
            // }

            this.showToast(
                'Enviado ao Autentique',
                result?.message || 'Documento enviado para assinatura eletrônica.',
                'success'
            );
        } catch (error) {
            console.error('Erro ao enviar para Autentique:', error);
            this.showError('Não foi possível enviar para o Autentique: ' + this.getErrorMessage(error));
        }
    }

    async withLoading(action, messages) {
        this.isLoading = true;
        this.loadingMessage = messages?.[0] ?? 'Carregando...';
        this.startProgressInterval(messages);

        try {
            return await action();
        } finally {
            this.clearProgressInterval();
            this.isLoading = false;
        }
    }

    startProgressInterval(messages) {
        if (!messages || messages.length < 2) return;
        let idx = 0;
        this._progressInterval = setInterval(() => {
            idx = (idx + 1) % messages.length;
            this.loadingMessage = messages[idx];
        }, 2500);
    }

    clearProgressInterval() {
        if (this._progressInterval) {
            clearInterval(this._progressInterval);
            this._progressInterval = null;
        }
    }

    openInNewTab(url, features = '') {
        window.open(url, '_blank', features);
    }

    showError(message) {
        this.showToast('Erro', message, 'error');
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        }
        if (Array.isArray(error.body)) {
            return error.body.map((entry) => entry.message).join(', ');
        }
        if (error.message) {
            return error.message;
        }

        return 'Erro desconhecido';
    }
}
