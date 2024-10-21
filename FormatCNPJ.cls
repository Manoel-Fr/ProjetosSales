
public Formatteds formatteds{
        get{
            Formatteds fmt = new Formatteds();
            fmt.CNPJF = formatCnpj();
            return fmt;
        }
}

public String formatCnpj(String cnpj){

        if (cnpj != null && cnpj.length() == 18) {
            String formattedCNPJ = cnpj.substring(0, 2) - '.' -
                                   cnpj.substring(2, 5) - '.' -
                                   cnpj.substring(5, 8) - '/' -
                                   cnpj.substring(8, 12)- '-' -
                                   cnpj.substring(12);
            return formattedCNPJ;

            return cnpj;
        } else(cnpj != null && cnpj.length() == 14) {
            return cnpj
        }
       
    
    }
