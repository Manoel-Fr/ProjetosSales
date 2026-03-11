import { LightningElement, track } from 'lwc';
import getClientes from '@salesforce/apex/VeiculoController.getClientes';

export default class ClientesVendas extends LightningElement {
    termoBusca = '';
    clienteSelecionadoId = null;
    isLoading = true;
    erroMensagem = '';

    @track clientes = [];

    connectedCallback() {
        this.buscarClientes();
    }

    async buscarClientes() {
        this.isLoading = true;
        this.erroMensagem = '';

        try {
            const result = await getClientes();
            this.clientes = Array.isArray(result) ? result : [];
        } catch (error) {
            this.erroMensagem = error?.body?.message || 'Erro ao buscar clientes.';
            this.clientes = [];
        } finally {
            this.isLoading = false;
        }
    }

    get clientesFiltrados() {
        let resultado = [...this.clientes];

        if (this.termoBusca) {
            const termo = this.termoBusca.toLowerCase();
            resultado = resultado.filter(cliente => {
                const nome = (cliente.Name || '').toLowerCase();
                const website = (cliente.Website || '').toLowerCase();
                const segmento = (cliente.Industry || '').toLowerCase();
                return nome.includes(termo) || website.includes(termo) || segmento.includes(termo);
            });
        }

        return resultado.map(cliente => {
            const nome = cliente.Name || 'Cliente sem nome';
            return {
                ...cliente,
                inicial: nome.charAt(0).toUpperCase() || 'C',
                websiteExibicao: cliente.Website || 'Website não informado',
                segmentoExibicao: cliente.Industry || 'Segmento não informado',
                cardClass:
                    cliente.Id === this.clienteSelecionadoId
                        ? 'cliente-card cliente-selecionado'
                        : 'cliente-card',
                buttonVariant: cliente.Id === this.clienteSelecionadoId ? 'success' : 'neutral'
            };
        });
    }

    get temClientes() {
        return this.clientesFiltrados.length > 0;
    }

    get quantidadeClientes() {
        return this.clientesFiltrados.length;
    }

    get temErro() {
        return Boolean(this.erroMensagem);
    }

    handleBusca(event) {
        this.termoBusca = event.target.value;
    }

    handleSelecionarCliente(event) {
        event.stopPropagation();

        const clienteId = event.currentTarget.dataset.id || event.target.dataset.id;
        const cliente = this.clientes.find(item => item.Id === clienteId);

        if (!cliente) {
            return;
        }

        this.clienteSelecionadoId = clienteId;
        this.dispatchEvent(
            new CustomEvent('selecionarcliente', {
                detail: cliente
            })
        );
    }
}
