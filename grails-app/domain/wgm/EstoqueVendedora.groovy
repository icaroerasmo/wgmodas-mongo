package wgm

class EstoqueVendedora {

	Integer quantidade

    Vendedora vendedora
    Produto produto

    static constraints = {
        vendedora nullable: false, unique: true
        produto nullable: false, unique: true
    }
}
