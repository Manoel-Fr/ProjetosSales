import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import GOOGLE_DOC_URL_FIELD from '@salesforce/schema/Opportunity.Google_Doc_Url__c';
import isAuthorized from '@salesforce/apex/GoogleAuthService.isAuthorized';
import ASSINATURA_ENVIADA_FIELD from '@salesforce/schema/Opportunity.AssEnv__c';
import getAuthorizationUrl from '@salesforce/apex/GoogleAuthService.getAuthorizationUrl';
import createDocumentFromOpportunity from '@salesforce/apex/GoogleDocsService.createDocumentFromOpportunity';
import sendDocumentToAutentique from '@salesforce/apex/AutentiqueService.sendDocumentToAutentique';
import getAssinaturas from '@salesforce/apex/AssinaturasController.getAssinaturas';

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
    signers = [];
    assinaturas = [];
    _progressInterval = null;
    _googleDocUrl = null;
    _assinaturaEnviada = false;

    @wire(getRecord, { recordId: '$recordId', fields: [GOOGLE_DOC_URL_FIELD, ASSINATURA_ENVIADA_FIELD] })
    wiredRecord({ data }) {
        if (data) {
            this._googleDocUrl = getFieldValue(data, GOOGLE_DOC_URL_FIELD);
            this._assinaturaEnviada = getFieldValue(data, ASSINATURA_ENVIADA_FIELD);
            this.getAssinaturas();
        }
    }

    get googleDocUrl() {
        return this._googleDocUrl;
    }

    get openDocsLabel() {
        return this._googleDocUrl ? 'Abrir documento' : 'Criar no Google Docs';
    }

    /**
     * Mostra o formulário de signatários quando a assinatura ainda NÃO foi enviada.
     * AssEnv__c (checkbox) = true significa "já enviado" → esconde formulário.
     */
    get assinaturaEnviada() {
        return this._assinaturaEnviada !== true;
    }

    connectedCallback() {
        this.checkAuthorization();
    }

    disconnectedCallback() {
        this.clearProgressInterval();
    }

    get isSendAutentiqueDisabled() {
        const temEmail = this.signerEmail?.trim() || this.signers?.length > 0;
        return !this.isAuthorized || this.isLoading || !temEmail;
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

    async getAssinaturas() {
        if (!this.recordId) return;
        try {
            const lista = await getAssinaturas({ opportunityId: this.recordId });
            const fmt = (d) => d ? new Date(d).toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' }) : null;
            this.assinaturas = (lista || []).map((a) => {
                const name = a.NmSign__c ?? a.DatagoProjects__NmSign__c ?? '';
                const email = a.EmlAss__c ?? a.DatagoProjects__EmlAss__c ?? '';
                const parts = name.trim().split(/\s+/);
                const initials = parts.length >= 2
                    ? (parts[0][0] + parts[parts.length - 1][0]).toUpperCase()
                    : (parts[0]?.[0] ?? '?').toUpperCase();
                const ns = 'DatagoProjects__';
                const status = a[`${ns}StsAss__c`] ?? a.StsAss__c ?? '';
                const dtAssn = a[`${ns}DtAssn__c`] ?? a.DtAssn__c ?? null;
                const dtEnEm = a[`${ns}DtEnEm__c`] ?? a.DtEnEm__c ?? null;
                const dtAbDc = a[`${ns}DtAbDc__c`] ?? a.DtAbDc__c ?? null;
                const signed = !!dtAssn;
                const statusClass = signed ? 'assinatura-status assinatura-status--signed' : 'assinatura-status assinatura-status--pending';
                return {
                    Id: a.Id, name, email, initials, status, statusClass,
                    dtEnviado: fmt(dtEnEm),
                    dtAberto: fmt(dtAbDc),
                    dtAssinado: fmt(dtAssn)
                };
            });
        } catch (error) {
            console.error('Erro ao buscar assinaturas:', error);
            this.assinaturas = [];
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
        if (this._googleDocUrl) {
            this.openInNewTab(this._googleDocUrl);
            return;
        }

        try {
            await this.withLoading(
                async () => {
                    const documentUrl = await createDocumentFromOpportunity({
                        opportunityId: this.recordId
                    });
                    this._googleDocUrl = documentUrl;
                //    this.openInNewTab(documentUrl);
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

    handleAddSigner() {
        if (!this.signerEmail?.trim()) return;
        this.signers = [...this.signers, { id: Date.now(), name: this.signerName?.trim() || this.signerEmail, email: this.signerEmail.trim() }];
        this.signerName = '';
        this.signerEmail = '';
    }

    handleRemoveSigner(event) {
        const i = parseInt(event.currentTarget.dataset.index, 10);
        this.signers = this.signers.filter((_, idx) => idx !== i);
    }

    get hasSigners() {
        return this.signers?.length > 0;
    }

    async handleSendToAutentique() {
        try {
            const signersToSend = this.signers.length > 0
                ? this.signers.map(({ name, email }) => ({ name, email }))
                : [{ name: this.signerName?.trim() || this.signerEmail?.trim(), email: this.signerEmail?.trim() }];

            if (!signersToSend[0]?.email) return;

            const result = await this.withLoading(
                () =>
                    sendDocumentToAutentique({
                        opportunityId: this.recordId,
                        signersJson: JSON.stringify(signersToSend)
                    }),
                LOADING_MESSAGES_AUTENTIQUE
            );

            this.showToast(
                'Enviado ao Autentique',
                result?.message || 'Documento enviado para assinatura eletrônica.',
                'success'
            );
            this.getAssinaturas();
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