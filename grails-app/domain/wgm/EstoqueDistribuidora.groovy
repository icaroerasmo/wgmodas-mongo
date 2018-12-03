package wgm

class EstoqueDistribuidora implements Serializable {

	Integer quantidade

    Distribuidora distribuidora
    Produto produto

    static constraints = {
        distribuidora nullable: false, unique: true
    }

    static mapping = {
        version false
        id composite: ['produto', 'distribuidora']
    }
}
