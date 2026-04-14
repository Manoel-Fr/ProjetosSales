#!/bin/bash
# =============================================================================
# Setup Google Cloud para integração Salesforce + Google Docs
# =============================================================================
# O que esse script faz:
#   1. Verifica se o gcloud está instalado
#   2. Faz login no Google Cloud
#   3. Coleta a URL da org Salesforce para montar o redirect URI
#   4. Cria um projeto novo
#   5. Verifica se billing está ativo
#   6. Ativa as APIs do Google Docs e Google Drive
#   7. Configura a tela de consentimento OAuth automaticamente
#   8. Abre o navegador na página de criar credencial OAuth
#   9. Coleta Client ID e Secret e salva em arquivo
# =============================================================================

set -e

# --- Cores ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Funções utilitárias ---
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC}   $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }
step()    { echo -e "\n${BOLD}==> $1${NC}"; }

# Abre o navegador no Mac, Linux ou WSL
open_browser() {
    local url="$1"
    if command -v open &>/dev/null; then
        open "$url"
    elif command -v xdg-open &>/dev/null; then
        xdg-open "$url"
    else
        warn "Não consegui abrir o navegador automaticamente."
        echo -e "  Acesse manualmente: ${BLUE}${url}${NC}"
    fi
}

# Lê input do usuário sem mostrar espaços extras
read_input() {
    local prompt="$1"
    local var_name="$2"
    echo -ne "${BOLD}${prompt}${NC} "
    read -r "$var_name"
}

# =============================================================================
# PASSO 1 — Verificar dependências
# =============================================================================
step "Verificando dependências"

if ! command -v gcloud &>/dev/null; then
    error "gcloud não encontrado.\nInstale em: https://cloud.google.com/sdk/docs/install"
fi
success "gcloud encontrado: $(gcloud --version | head -1)"

# =============================================================================
# PASSO 2 — Login
# =============================================================================
step "Login no Google Cloud"

CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)

if [ -z "$CURRENT_ACCOUNT" ] || [ "$CURRENT_ACCOUNT" = "(unset)" ]; then
    info "Abrindo navegador para login..."
    gcloud auth login --quiet
else
    success "Já logado como: ${CURRENT_ACCOUNT}"
    read_input "Usar essa conta? [S/n]:" USE_CURRENT
    if [[ "$USE_CURRENT" =~ ^[Nn]$ ]]; then
        gcloud auth login --quiet
    fi
fi

ACCOUNT=$(gcloud config get-value account 2>/dev/null)
success "Conta ativa: ${ACCOUNT}"

# =============================================================================
# PASSO 3 — Coletar URL da org Salesforce
# =============================================================================
step "URL da org Salesforce"

echo ""
info "Informe a URL base da sua org Salesforce."
info "Exemplos: https://minhaempresa.salesforce.com"
info "          https://minhaempresa.my.salesforce.com"
echo ""

read_input "URL da org Salesforce:" SF_ORG_URL

# Remove barra final se houver
SF_ORG_URL="${SF_ORG_URL%/}"

if [[ ! "$SF_ORG_URL" =~ ^https?:// ]]; then
    error "URL inválida. Deve começar com https://"
fi

SF_REDIRECT_URI="${SF_ORG_URL}/apex/GoogleAuthCallback"
success "URI de redirecionamento: ${SF_REDIRECT_URI}"

# =============================================================================
# PASSO 4 — Criar projeto
# =============================================================================
step "Criar projeto no Google Cloud"

echo ""
info "O Project ID precisa ser único globalmente (só letras minúsculas, números e hífens)."
info "Exemplo: minha-empresa-salesforce"
echo ""

read_input "Nome do projeto (Project ID):" PROJECT_ID

# Validação básica do Project ID
if [[ ! "$PROJECT_ID" =~ ^[a-z][a-z0-9-]{4,28}[a-z0-9]$ ]]; then
    error "Project ID inválido. Use entre 6 e 30 caracteres: letras minúsculas, números e hífens.\nNão pode começar ou terminar com hífen."
fi

# Verifica se o projeto já existe
if gcloud projects describe "$PROJECT_ID" &>/dev/null; then
    warn "Projeto '${PROJECT_ID}' já existe. Usando o projeto existente."
else
    info "Criando projeto '${PROJECT_ID}'..."
    gcloud projects create "$PROJECT_ID" --name="$PROJECT_ID" --quiet
    success "Projeto criado: ${PROJECT_ID}"
fi

# Define o projeto como ativo
gcloud config set project "$PROJECT_ID" --quiet
success "Projeto ativo definido: ${PROJECT_ID}"

# =============================================================================
# PASSO 5 — Ativar APIs (Google Docs e Drive são gratuitas, billing nao e necessario)
# =============================================================================
step "Ativando APIs necessárias"

info "Isso pode levar alguns segundos..."

APIS=(
    "docs.googleapis.com"
    "drive.googleapis.com"
    "iap.googleapis.com"
)

for API in "${APIS[@]}"; do
    info "Ativando ${API}..."
    gcloud services enable "$API" --quiet
    success "${API} ativada"
done

# =============================================================================
# PASSO 7 — Configurar tela de consentimento OAuth (automatico via REST API)
# =============================================================================
step "Configurando tela de consentimento OAuth"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
ACCESS_TOKEN=$(gcloud auth print-access-token)

# Verifica se já existe um brand configurado
info "Verificando tela de consentimento existente..."
EXISTING=$(curl -s \
    "https://iap.googleapis.com/v1/projects/${PROJECT_NUMBER}/brands" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}")

BRAND_NAME=$(echo "$EXISTING" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$BRAND_NAME" ]; then
    success "Tela de consentimento já configurada"
else
    info "Criando tela de consentimento OAuth..."
    RESULT=$(curl -s -X POST \
        "https://iap.googleapis.com/v1/projects/${PROJECT_NUMBER}/brands" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{
            \"applicationTitle\": \"Salesforce Google Docs\",
            \"supportEmail\": \"${ACCOUNT}\"
        }")

    BRAND_NAME=$(echo "$RESULT" | grep -o '"name":"[^"]*"' | head -1 | cut -d'"' -f4)

    if [ -n "$BRAND_NAME" ]; then
        success "Tela de consentimento configurada automaticamente"
    else
        warn "Não foi possível configurar automaticamente. Abrindo no navegador..."
        echo ""
        echo -e "  ${BOLD}1.${NC} Selecione: ${GREEN}Externo${NC} e clique em ${GREEN}Criar${NC}"
        echo -e "  ${BOLD}2.${NC} Preencha:"
        echo -e "     • ${BOLD}Nome do app${NC}: Salesforce Google Docs"
        echo -e "     • ${BOLD}E-mail de suporte${NC}: ${ACCOUNT}"
        echo -e "     • ${BOLD}E-mail do desenvolvedor${NC}: ${ACCOUNT}"
        echo -e "  ${BOLD}3.${NC} Clique em ${GREEN}Salvar e continuar${NC} em todas as telas"
        echo ""
        open_browser "https://console.cloud.google.com/apis/credentials/consent?project=${PROJECT_ID}"
        read_input "Pressione ENTER quando terminar..." _PAUSE
    fi
fi

# =============================================================================
# PASSO 8 — Criar credencial OAuth
# =============================================================================
step "Criar credencial OAuth 2.0 (manual)"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}AÇÃO NECESSÁRIA — Criar Credencial OAuth${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Siga os passos na página que vai abrir:"
echo ""
echo -e "  ${BOLD}1.${NC} Clique em ${GREEN}+ Criar credenciais${NC} → ${GREEN}ID do cliente OAuth${NC}"
echo -e "  ${BOLD}2.${NC} Tipo: ${GREEN}Aplicativo da Web${NC}"
echo -e "  ${BOLD}3.${NC} Nome: qualquer nome (ex: Salesforce)"
echo -e "  ${BOLD}4.${NC} Em ${BOLD}URIs de redirecionamento autorizados${NC}, clique em ${GREEN}+ Adicionar URI${NC}"
echo -e "     Cole exatamente este valor:"
echo ""
echo -e "     ${GREEN}${SF_REDIRECT_URI}${NC}"
echo ""
echo -e "  ${BOLD}5.${NC} Clique em ${GREEN}Criar${NC}"
echo -e "  ${BOLD}6.${NC} Uma janela vai aparecer com o ${BOLD}Client ID${NC} e ${BOLD}Client Secret${NC} — copie os dois"
echo ""

CREDENTIALS_URL="https://console.cloud.google.com/apis/credentials?project=${PROJECT_ID}"
info "Abrindo no navegador..."
open_browser "$CREDENTIALS_URL"

echo ""
read_input "Pressione ENTER quando tiver o Client ID e Secret em mãos..." _PAUSE

# =============================================================================
# PASSO 9 — Coletar credenciais e salvar em arquivo
# =============================================================================
step "Cole as credenciais geradas"

echo ""
read_input "Client ID:" CLIENT_ID
read_input "Client Secret:" CLIENT_SECRET

if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
    error "Client ID e Client Secret não podem estar vazios."
fi

# Salva as credenciais em arquivo
OUTPUT_FILE=".env.google-credentials"
cat > "$OUTPUT_FILE" <<EOF
GOOGLE_CLIENT_ID=${CLIENT_ID}
GOOGLE_CLIENT_SECRET=${CLIENT_SECRET}
GOOGLE_PROJECT_ID=${PROJECT_ID}
SALESFORCE_REDIRECT_URI=${SF_REDIRECT_URI}
EOF
success "Credenciais salvas em: ${OUTPUT_FILE}"

# =============================================================================
# PASSO 10 — Resumo final
# =============================================================================
step "Configuração concluída!"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  Cole esses valores no Salesforce Custom Settings${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Caminho no Salesforce:${NC}"
echo -e "  Setup → Custom Settings → Google Credentials → Manage → New"
echo ""
echo -e "  ${BOLD}Client ID:${NC}"
echo -e "  ${GREEN}${CLIENT_ID}${NC}"
echo ""
echo -e "  ${BOLD}Client Secret:${NC}"
echo -e "  ${GREEN}${CLIENT_SECRET}${NC}"
echo ""
echo -e "  ${BOLD}Template Document ID:${NC}"
echo -e "  (ID do documento Google Docs que você usa como template)"
echo -e "  Extraia da URL: docs.google.com/document/d/${YELLOW}ESTE-TRECHO${NC}/edit"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Próximo passo:${NC} Abra uma Oportunidade no Salesforce"
echo -e "  e clique em ${GREEN}Conectar Google${NC} para autorizar o acesso."
echo ""
success "Setup concluído para o projeto: ${PROJECT_ID}"
