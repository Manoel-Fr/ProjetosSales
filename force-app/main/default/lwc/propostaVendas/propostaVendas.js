import { LightningElement, api, track } from 'lwc';

export default class PropostaVendas extends LightningElement {
    @api clienteSelecionado = null;
    @api itensCarrinho = [];

    @track descontoPercentual = 0;
    @track observacoes = '';

    get temCliente() {
        return Boolean(this.clienteSelecionado);
    }

    get temItens() {
        return Array.isArray(this.itensCarrinho) && this.itensCarrinho.length > 0;
    }

    get quantidadeItens() {
        return this.temItens ? this.itensCarrinho.length : 0;
    }

    get subtotal() {
        if (!this.temItens) {
            return 0;
        }
        return this.itensCarrinho.reduce((soma, item) => soma + (Number(item.preco) || 0), 0);
    }

    get descontoPercentualNormalizado() {
        const percentual = Number(this.descontoPercentual);

        if (Number.isNaN(percentual)) {
            return 0;
        }

        if (percentual < 0) {
            return 0;
        }

        if (percentual > 100) {
            return 100;
        }

        return percentual;
    }

    get descontoValor() {
        return this.subtotal * (this.descontoPercentualNormalizado / 100);
    }

    get totalFinal() {
        const total = this.subtotal - this.descontoValor;
        return total > 0 ? total : 0;
    }

    get subtotalFormatado() {
        return this.formatarMoeda(this.subtotal);
    }

    get descontoValorFormatado() {
        return this.formatarMoeda(this.descontoValor);
    }

    get totalFinalFormatado() {
        return this.formatarMoeda(this.totalFinal);
    }

    get itensResumo() {
        if (!this.temItens) {
            return [];
        }

        return this.itensCarrinho.map(item => ({
            ...item,
            precoExibicao: this.formatarMoeda(item.preco)
        }));
    }

    get nomeCliente() {
        return this.clienteSelecionado?.Name || 'Cliente não selecionado';
    }

    get websiteCliente() {
        return this.clienteSelecionado?.Website || 'Website não informado';
    }

    get segmentoCliente() {
        return this.clienteSelecionado?.Industry || 'Segmento não informado';
    }

    get podeFinalizar() {
        return this.temCliente && this.temItens;
    }

    get finalizarDesabilitado() {
        return !this.podeFinalizar;
    }

    get mostrarAvisoPendencias() {
        return !this.podeFinalizar;
    }

    get mensagemPendencias() {
        if (!this.temCliente && !this.temItens) {
            return 'Selecione um cliente e adicione veículos no carrinho para continuar.';
        }

        if (!this.temCliente) {
            return 'Selecione um cliente antes de finalizar a proposta.';
        }

        return 'Adicione ao menos um veículo no carrinho para gerar a proposta.';
    }

    get textoItens() {
        return this.quantidadeItens === 1 ? 'veículo' : 'veículos';
    }

    handleDescontoChange(event) {
        const novoValor = Number(event.detail.value);
        this.descontoPercentual = Number.isNaN(novoValor) ? 0 : novoValor;
    }

    handleObservacoesChange(event) {
        this.observacoes = event.target.value;
    }

    handleCancelar() {
        this.dispatchEvent(new CustomEvent('cancelar'));
    }

    handleFinalizarVenda() {
        if (!this.podeFinalizar) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('finalizarvenda', {
                detail: {
                    cliente: this.clienteSelecionado,
                    itens: this.itensCarrinho,
                    quantidadeItens: this.quantidadeItens,
                    subtotal: this.subtotal,
                    descontoPercentual: this.descontoPercentualNormalizado,
                    descontoValor: this.descontoValor,
                    totalFinal: this.totalFinal,
                    observacoes: this.observacoes
                }
            })
        );
    }

    formatarMoeda(valor) {
        return (Number(valor) || 0).toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }
}
