package wgm

class CobrancaVendedora {

    Long id
	Integer parcela
	Date dataVencimento
	Boolean flagPagamento

    Pedido pedido

    static mapping = {
        version false
    }

    static constraints = {
        parcela blank: false, nullable: false
        dataVencimento nullable: false
        flagPagamento nullable: false
    }
}
