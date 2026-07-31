import { LightningElement, api, track } from 'lwc';

export default class PropostaVendas extends LightningElement {
    
    // ========== PROPRIEDADES RECEBIDAS DO PAI ==========
    @api clienteSelecionado = null;
    @api itensCarrinho = [];

    // ========== PROPRIEDADES INTERNAS ==========
    @track formaPagamento = 'avista';
    @track percentualDesconto = 0;
    @track numeroParcelas = '12';
    @track observacoes = '';

    // ========== OPÇÕES DE COMBOBOX ==========
    
    get opcoesFormaPagamento() {
        return [
            { label: 'À Vista', value: 'avista' },
            { label: 'Financiamento', value: 'financiamento' },
            { label: 'Consórcio', value: 'consorcio' },
            { label: 'Troca + Valor', value: 'troca' }
        ];
    }

    get opcoesParcelas() {
        return [
            { label: '12x', value: '12' },
            { label: '24x', value: '24' },
            { label: '36x', value: '36' },
            { label: '48x', value: '48' },
            { label: '60x', value: '60' }
        ];
    }

    // ========== VALIDAÇÕES ==========
    
    get temCliente() {
        return this.clienteSelecionado !== null;
    }

    get temVeiculos() {
        return this.itensCarrinho && this.itensCarrinho.length > 0;
    }

    get faltaDados() {
        return !this.temCliente || !this.temVeiculos;
    }

    get quantidadeVeiculos() {
        return this.itensCarrinho ? this.itensCarrinho.length : 0;
    }

    // ========== DADOS DO CLIENTE ==========
    
    get clienteEmail() {
        return this.clienteSelecionado?.Email || 'Não informado';
    }

    get clienteTelefone() {
        return this.clienteSelecionado?.Phone || 'Não informado';
    }

    // ========== CÁLCULOS FINANCEIROS ==========
    
    get subtotal() {
        if (!this.itensCarrinho) return 0;
        return this.itensCarrinho.reduce((soma, item) => {
            return soma + (item.preco || 0);
        }, 0);
    }

    get subtotalFormatado() {
        return this.formatarMoeda(this.subtotal);
    }

    get temDesconto() {
        return this.percentualDesconto > 0;
    }

    get valorDesconto() {
        return (this.subtotal * this.percentualDesconto) / 100;
    }

    get valorDescontoFormatado() {
        return this.formatarMoeda(this.valorDesconto);
    }

    get totalFinal() {
        return this.subtotal - this.valorDesconto;
    }

    get totalFinalFormatado() {
        return this.formatarMoeda(this.totalFinal);
    }

    get mostrarParcelas() {
        return this.formaPagamento === 'financiamento';
    }

    get valorParcela() {
        if (!this.mostrarParcelas) return 0;
        const parcelas = parseInt(this.numeroParcelas, 10);
        return this.totalFinal / parcelas;
    }

    get valorParcelaFormatado() {
        return this.formatarMoeda(this.valorParcela);
    }

    // ========== FORMATAÇÃO ==========
    
    formatarMoeda(valor) {
        return valor.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    // ========== HANDLERS ==========
    
    handleFormaPagamentoChange(event) {
        this.formaPagamento = event.detail.value;
    }

    handleDescontoChange(event) {
        let valor = parseFloat(event.target.value) || 0;
        // Limita o desconto entre 0 e 30%
        if (valor < 0) valor = 0;
        if (valor > 30) valor = 30;
        this.percentualDesconto = valor;
    }

    handleParcelasChange(event) {
        this.numeroParcelas = event.detail.value;
    }

    handleObservacoesChange(event) {
        this.observacoes = event.target.value;
    }

    handleCancelar() {
        // Dispara evento para o pai limpar/cancelar
        this.dispatchEvent(new CustomEvent('cancelar'));
    }

    handleFinalizarVenda() {
        // Monta objeto com todos os dados da proposta
        const dadosProposta = {
            cliente: this.clienteSelecionado,
            veiculos: this.itensCarrinho,
            formaPagamento: this.formaPagamento,
            percentualDesconto: this.percentualDesconto,
            valorDesconto: this.valorDesconto,
            subtotal: this.subtotal,
            totalFinal: this.totalFinal,
            numeroParcelas: this.mostrarParcelas ? this.numeroParcelas : null,
            valorParcela: this.mostrarParcelas ? this.valorParcela : null,
            observacoes: this.observacoes
        };

        // Dispara evento com os dados para o componente pai
        this.dispatchEvent(new CustomEvent('finalizarvenda', {
            detail: dadosProposta
        }));
    }
}