public with sharing class GoogleAuthCallbackController {
    public Boolean isSuccess { get; set; }
    public String errorMessage { get; set; }
    public String opportunityId { get; set; }

    public GoogleAuthCallbackController() {
        isSuccess = false;
        errorMessage = '';
        opportunityId = '';
    }

    public PageReference processCallback() {
        try {
            Map<String, String> params = ApexPages.currentPage().getParameters();
            String authError = params.get('error');
            if (String.isNotBlank(authError)) {
                return setError('Erro do Google: ' + authError);
            }

            String code = params.get('code');
            if (String.isBlank(code)) {
                return setError('Código de autorização não recebido.');
            }

            Map<String, String> tokens = GoogleAuthService.exchangeCodeForTokens(code);
            if (!tokens.containsKey('access_token')) {
                return setError('Não foi possível obter o token de acesso.');
            }

            isSuccess = true;
            String state = params.get('state');
            opportunityId = String.isNotBlank(state) ? state : '';
        } catch (Exception e) {
            return setError('Erro: ' + e.getMessage());
        }

        return null;
    }

    private PageReference setError(String message) {
        isSuccess = false;
        errorMessage = message;
        return null;
    }
}
