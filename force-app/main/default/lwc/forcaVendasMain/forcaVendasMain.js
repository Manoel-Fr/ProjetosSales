import { LightningElement, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const TAB_SEQUENCE = ['estoque', 'clientes', 'carrinho', 'proposta'];

const TAB_LABELS = {
    estoque: 'Estoque de Veículos',
    clientes: 'Seleção de Cliente',
    carrinho: 'Resumo do Carrinho',
    proposta: 'Finalização da Proposta'
};

export default class ForcaVendasMain extends LightningElement {
    @api titulo = 'Sistema de gestão de vendas de veículos';

    activeTab = 'estoque';

    @track clienteSelecionado = null;
    @track itensCarrinho = [];

    get nomeClienteSelecionado() {
        return this.clienteSelecionado ? this.clienteSelecionado.Name : 'Nenhum selecionado';
    }

    get quantidadeCarrinho() {
        return this.itensCarrinho.length;
    }

    get totalCarrinho() {
        const total = this.itensCarrinho.reduce((soma, item) => soma + (Number(item.preco) || 0), 0);

        return total.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    get temItensCarrinho() {
        return this.itensCarrinho.length > 0;
    }

    get activeTabLabel() {
        return TAB_LABELS[this.activeTab] || TAB_LABELS.estoque;
    }

    get activeTabIndex() {
        const index = TAB_SEQUENCE.indexOf(this.activeTab);
        return index >= 0 ? index : 0;
    }

    get etapaAtualNumero() {
        return this.activeTabIndex + 1;
    }

    get progressoPercent() {
        return Math.round(((this.activeTabIndex + 1) / TAB_SEQUENCE.length) * 100);
    }

    get progressoStyle() {
        return `width: ${this.progressoPercent}%;`;
    }

    get estoqueCardClass() {
        return this.getCardClass('estoque');
    }

    get carrinhoCardClass() {
        return this.getCardClass('carrinho');
    }

    get clientesCardClass() {
        return this.getCardClass('clientes');
    }

    get propostaCardClass() {
        return this.getCardClass('proposta');
    }

    get isEstoqueAtivo() {
        return this.activeTab === 'estoque';
    }

    get isCarrinhoAtivo() {
        return this.activeTab === 'carrinho';
    }

    get isClientesAtivo() {
        return this.activeTab === 'clientes';
    }

    get isPropostaAtivo() {
        return this.activeTab === 'proposta';
    }

    handleNavigateEstoque(event) {
        this.navigateToTab('estoque', event);
    }

    handleNavigateCarrinho(event) {
        this.navigateToTab('carrinho', event);
    }

    handleNavigateClientes(event) {
        this.navigateToTab('clientes', event);
    }

    handleNavigateProposta(event) {
        this.navigateToTab('proposta', event);
    }

    handleTabChange(event) {
        this.navigateToTab(event.target.value);
    }

    handleAddCarrinho(event) {
        const veiculo = event.detail;
        const jaExiste = this.itensCarrinho.some(item => item.Id === veiculo.Id);

        if (jaExiste) {
            this.mostrarToast('Atenção', 'Este veículo já está no carrinho!', 'warning');
            return;
        }

        this.itensCarrinho = [...this.itensCarrinho, veiculo];
        this.mostrarToast('Sucesso', 'Veículo adicionado ao carrinho!', 'success');
    }

    handleSelecionarCliente(event) {
        this.clienteSelecionado = event.detail;
        this.mostrarToast('Cliente selecionado', this.clienteSelecionado.Name, 'success');
    }

    handleFinalizar() {
        this.navigateToTab('proposta');
    }

    handleRemoverItem(event) {
        const itemId = event.detail.id;
        this.itensCarrinho = this.itensCarrinho.filter(item => item.Id !== itemId);
        this.mostrarToast('Removido', 'Veículo removido do carrinho', 'info');
    }

    handleLimparTodoCarrinho() {
        this.itensCarrinho = [];
        this.mostrarToast('Carrinho limpo', 'Todos os veículos foram removidos', 'info');
    }

    handleCancelarProposta() {
        this.navigateToTab('carrinho');
        this.mostrarToast('Cancelado', 'Proposta cancelada. Você pode continuar editando.', 'info');
    }

    handleFinalizarVenda(event) {
        const dadosProposta = event.detail;
        const totalFinal = Number(dadosProposta.totalFinal) || 0;

        this.mostrarToast(
            'Venda realizada!',
            `Venda para ${dadosProposta.cliente.Name} no valor de R$ ${totalFinal.toLocaleString('pt-BR', { minimumFractionDigits: 2 })}`,
            'success'
        );

        this.limparCarrinho();
        this.navigateToTab('estoque');
    }

    getCardClass(tabName) {
        return this.activeTab === tabName ? 'nav-card nav-card-ativo' : 'nav-card';
    }

    navigateToTab(tabName, event) {
        if (!TAB_SEQUENCE.includes(tabName)) {
            return;
        }

        if (event && event.type === 'keydown') {
            const isActivationKey = event.key === 'Enter' || event.key === ' ';
            if (!isActivationKey) {
                return;
            }
            event.preventDefault();
        }

        this.activeTab = tabName;
    }

    limparCarrinho() {
        this.itensCarrinho = [];
        this.clienteSelecionado = null;
    }

    mostrarToast(titulo, mensagem, variante) {
        this.dispatchEvent(
            new ShowToastEvent({
                title: titulo,
                message: mensagem,
                variant: variante
            })
        );
    }
}
