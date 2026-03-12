/**
 * Serviço de autenticação OAuth2 com Google.
 * Responsável por URL de autorização, troca de código por tokens e refresh.
 */
public with sharing class GoogleAuthService {

    private static final String GOOGLE_AUTH_URL  = 'https://accounts.google.com/o/oauth2/v2/auth';
    private static final String GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
    private static final String SCOPES =
        'https://www.googleapis.com/auth/documents ' +
        'https://www.googleapis.com/auth/drive.file ' +
        'https://www.googleapis.com/auth/drive';
    private static final String REDIRECT_URI =
        'https://empathetic-panda-pf0ols-dev-ed.trailblaze.my.salesforce.com/apex/GoogleAuthCallback';

    public static Google_Credentials__c getCredentials() {
        Google_Credentials__c c = Google_Credentials__c.getOrgDefaults();
        if (c == null || String.isBlank(c.Client_ID__c)) {
            throw new GoogleDocsException('Credenciais do Google não configuradas.');
        }
        return c;
    }

    @AuraEnabled
    public static String getAuthorizationUrl(String state) {
        Google_Credentials__c c = getCredentials();

        Map<String, String> params = new Map<String, String>{
            'client_id'     => c.Client_ID__c,
            'redirect_uri'  => REDIRECT_URI,
            'response_type' => 'code',
            'scope'         => SCOPES,
            'access_type'   => 'offline',
            'prompt'        => 'consent'
        };

        if (String.isNotBlank(state)) {
            params.put('state', state);
        }

        return GOOGLE_AUTH_URL + '?' + buildQueryString(params);
    }

    @AuraEnabled
    public static Map<String, String> exchangeCodeForTokens(String code) {
        Google_Credentials__c c = getCredentials();

        String body = buildQueryString(new Map<String, String>{
            'code'          => code,
            'client_id'     => c.Client_ID__c,
            'client_secret' => c.Client_Secret__c,
            'redirect_uri'  => REDIRECT_URI,
            'grant_type'    => 'authorization_code'
        });

        HttpResponse res = GoogleApiClient.sendRequest(
            GOOGLE_TOKEN_URL,
            'POST',
            null,
            'application/x-www-form-urlencoded',
            body
        );

        Map<String, Object> json =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        if (json.containsKey('refresh_token')) {
            saveRefreshToken((String) json.get('refresh_token'));
        }

        return new Map<String, String>{
            'access_token'  => (String) json.get('access_token'),
            'refresh_token' => (String) json.get('refresh_token')
        };
    }

    // Cache do token para evitar refresh duplicado na mesma transação (ex: createDocument + export).
    private static String cachedAccessToken;
    private static Long cachedTokenExpiresAt;

    public static String refreshAccessToken() {
        Long now = System.currentTimeMillis();
        if (cachedAccessToken != null && cachedTokenExpiresAt != null && cachedTokenExpiresAt > now) {
            return cachedAccessToken;
        }

        Google_Credentials__c c = getCredentials();

        if (String.isBlank(c.Refresh_Token__c)) {
            throw new GoogleDocsException('Refresh token não encontrado.');
        }

        String body = buildQueryString(new Map<String, String>{
            'client_id'     => c.Client_ID__c,
            'client_secret' => c.Client_Secret__c,
            'refresh_token' => c.Refresh_Token__c,
            'grant_type'    => 'refresh_token'
        });

        HttpResponse res = GoogleApiClient.sendRequest(
            GOOGLE_TOKEN_URL,
            'POST',
            null,
            'application/x-www-form-urlencoded',
            body
        );

        Map<String, Object> json =
            (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

        cachedAccessToken = (String) json.get('access_token');
        Object expiresInObj = json.get('expires_in');
        Integer expiresIn = expiresInObj != null ? GoogleApiClient.toInt(expiresInObj) : 3600;
        // Buffer de 5 min antes do vencimento; mínimo 60s para tokens curtos.
        Integer validSeconds = Math.max(expiresIn - 300, 60);
        cachedTokenExpiresAt = now + (validSeconds * 1000L);

        return cachedAccessToken;
    }

    @AuraEnabled(cacheable=true)
    public static Boolean isAuthorized() {
        Google_Credentials__c c = Google_Credentials__c.getOrgDefaults();
        return c != null && String.isNotBlank(c.Refresh_Token__c);
    }

    private static void saveRefreshToken(String token) {
        Google_Credentials__c c = Google_Credentials__c.getOrgDefaults();
        c.Refresh_Token__c = token;
        upsert c;
    }

    private static String buildQueryString(Map<String, String> p) {
        List<String> parts = new List<String>();
        for (String k : p.keySet()) {
            parts.add(
                EncodingUtil.urlEncode(k, 'UTF-8') + '=' +
                EncodingUtil.urlEncode(p.get(k), 'UTF-8')
            );
        }
        return String.join(parts, '&');
    }
}
