package wgm

class EstoqueVendedora implements Serializable{

	Integer quantidade

    Vendedora vendedora
    Produto produto

    static constraints = {
        vendedora nullable: false, unique: true
        produto nullable: false, unique: true
    }

    static mapping = {
        version false
        id composite: ['produto', 'vendedora']
    }
}
