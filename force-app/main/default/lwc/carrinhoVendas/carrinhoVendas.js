import { LightningElement, api } from 'lwc';

export default class CarrinhoVendas extends LightningElement {
    @api itensCarrinho = [];
    @api clienteSelecionado = null;

    get temItensNoCarrinho() {
        return Array.isArray(this.itensCarrinho) && this.itensCarrinho.length > 0;
    }

    get quantidadeItens() {
        return Array.isArray(this.itensCarrinho) ? this.itensCarrinho.length : 0;
    }

    get textoItens() {
        return this.quantidadeItens === 1 ? 'veículo' : 'veículos';
    }

    get quantidadeTexto() {
        if (!this.temItensNoCarrinho) {
            return 'Nenhum veículo adicionado';
        }
        return `${this.quantidadeItens} ${this.textoItens} no carrinho`;
    }

    get nomeClienteSelecionado() {
        return this.clienteSelecionado?.Name || 'Não definido';
    }

    get total() {
        if (!Array.isArray(this.itensCarrinho)) {
            return 0;
        }

        return this.itensCarrinho.reduce((soma, item) => soma + (Number(item.preco) || 0), 0);
    }

    get valorComissao() {
        if (!Array.isArray(this.itensCarrinho)) {
            return 0;
        }
        return this.itensCarrinho.reduce((soma, item) => {
            const preco = Number(item.preco) || 0;
            const percentual = Number(item.comissao) || 0;
            return soma + preco * (percentual / 100);
        }, 0);
    }

    get totalFormatado() {
        const totalMenosComissao = this.total - this.valorComissao;
        return totalMenosComissao.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }
    get subtotalFormatado() {
        return this.total.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    
    get custoFormatado() {
        return this.custo.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }
    get lucroFormatado() {
        return this.lucro.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }
      
    get comissaoFormatado() {
        return this.valorComissao.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }
    get precoFormatado() {
        return this.preco.toLocaleString('pt-BR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    handleFinalizar() {
        this.dispatchEvent(new CustomEvent('finalizar'));
    }

    handleRemoverItem(event) {
        const itemId = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('removeritem', {
                detail: { id: itemId }
            })
        );
    }

    handleLimparCarrinho() {
        this.dispatchEvent(new CustomEvent('limparcarrinho'));
    }
}
