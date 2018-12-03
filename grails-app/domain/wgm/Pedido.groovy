package wgm

class Pedido {

    Long id
	Integer quantidade
	Float desconto
	Float precoVenda

    Vendedora vendedora
	Cliente cliente

    static hasOne = [
        distribuidora:Distribuidora
    ]

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
        codigo blank: false, nullable: false, unique: true
        quantidade blank: false, nullable: false
        desconto blank: false, nullable: false
        precoVenda blank: false, nullable: false
    }
}
