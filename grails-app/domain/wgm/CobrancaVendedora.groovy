package wgm

class CobrancaVendedora {

    Long id
	Float parcela
	Date dataVencimento
	Boolean flagPagamento

    Pedido pedido
    Vendedora vendedora

    static constraints = {
        parcela blank: false, nullable: false
        dataVencimento nullable: false
        flagPagamento nullable: false
        vendedora nullable: false
    }
}
