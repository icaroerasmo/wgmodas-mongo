package wgm

class Pedido {

    Long id
	Integer quantidade
	Float desconto
	Float precoVenda

    Vendedora vendedora
	Cliente cliente

    static hasMany = [
        produtos:Produto
    ]

    static mapping = {
        version false
        produtos joinTable: [
                        name: 'pedido_produto',
                        key: 'pedido_id',
                        column: 'id'
                        ] 
    }

    static constraints = {
        quantidade blank: false, nullable: false
        desconto blank: false, nullable: false
        precoVenda blank: false, nullable: false
    }
}
