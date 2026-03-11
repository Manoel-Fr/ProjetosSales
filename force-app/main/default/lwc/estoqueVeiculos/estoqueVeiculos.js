import { LightningElement, track, wire } from 'lwc';
import getVeiculos from '@salesforce/apex/VeiculoController.getVeiculos';
import getMarcas from '@salesforce/apex/VeiculoController.getMarcas';
import getAnos from '@salesforce/apex/VeiculoController.getAnos';

export default class EstoqueVeiculos extends LightningElement {
    termoBusca = '';
    filtroMarca = '';
    filtroAno = '';
    isLoading = true;
    erro = null;

    @track veiculos = [];
    @track listaMarcas = [];
    @track listaAnos = [];

    @wire(getVeiculos)
    wiredVeiculos({ error, data }) {
        this.isLoading = false;

        if (data) {
            this.veiculos = data;
            this.erro = null;
            return;
        }

        if (error) {
            this.erro = error.body?.message || 'Erro ao carregar veículos.';
            this.veiculos = [];
        }
    }

    @wire(getMarcas)
    wiredMarcas({ error, data }) {
        if (data) {
            this.listaMarcas = data;
        } else if (error) {
            this.listaMarcas = [];
        }
    }

    @wire(getAnos)
    wiredAnos({ error, data }) {
        if (data) {
            this.listaAnos = data;
        } else if (error) {
            this.listaAnos = [];
        }
    }

    get veiculosFiltrados() {
        let resultado = [...this.veiculos];

        if (this.termoBusca) {
            const termo = this.termoBusca.toLowerCase();
            resultado = resultado.filter(veiculo => {
                const marca = (veiculo.marca || '').toLowerCase();
                const modelo = (veiculo.modelo || '').toLowerCase();
                const nome = (veiculo.nome || '').toLowerCase();
                const placa = (veiculo.placa || '').toLowerCase();
                return (
                    marca.includes(termo) ||
                    modelo.includes(termo) ||
                    nome.includes(termo) ||
                    placa.includes(termo)
                );
            });
        }

        if (this.filtroMarca) {
            resultado = resultado.filter(veiculo => veiculo.marca === this.filtroMarca);
        }

        if (this.filtroAno) {
            resultado = resultado.filter(veiculo => String(veiculo.ano) === String(this.filtroAno));
        }

        return resultado.map(veiculo => {
            let statusClass = 'status-indefinido';
            if (veiculo.status === 'Disponível') {
                statusClass = 'status-disponivel';
            } else if (veiculo.status === 'Reservado') {
                statusClass = 'status-reservado';
            }

            return {
                ...veiculo,
                statusClass
            };
        });
    }

    get temVeiculos() {
        return this.veiculosFiltrados.length > 0;
    }

    get quantidadeResultados() {
        return this.veiculosFiltrados.length;
    }

    get temErro() {
        return Boolean(this.erro);
    }

    get opcoesMarca() {
        return [{ label: 'Todas', value: '' }, ...this.listaMarcas.map(marca => ({ label: marca, value: marca }))];
    }

    get opcoesAno() {
        return [{ label: 'Todos', value: '' }, ...this.listaAnos.map(ano => ({ label: ano, value: ano }))];
    }

    handleBusca(event) {
        this.termoBusca = event.target.value;
    }

    handleFiltroMarca(event) {
        this.filtroMarca = event.detail.value;
    }

    handleFiltroAno(event) {
        this.filtroAno = event.detail.value;
    }

    handleLimparFiltros() {
        this.termoBusca = '';
        this.filtroMarca = '';
        this.filtroAno = '';
    }

    handleAddCarrinho(event) {
        const veiculoId = event.currentTarget.dataset.id;
        const veiculo = this.veiculos.find(item => item.Id === veiculoId);

        if (!veiculo) {
            return;
        }

        this.dispatchEvent(
            new CustomEvent('addcarrinho', {
                detail: veiculo
            })
        );
    }
}
