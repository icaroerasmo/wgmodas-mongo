package wgm

class EstoqueDistribuidora {

	Integer quantidade

    Distribuidora distribuidora
    Produto produto

    static constraints = {
        distribuidora nullable: false, unique: true
        produto nullable: false, unique: true
    }
}
