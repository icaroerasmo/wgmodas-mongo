package wgm

class Pedido {

    Long id
	Integer codigo
	Integer quantidade
	Integer desconto
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
        table 'PEDIDO'
        distribuidora joinTable: [
                        name: 'PEDIDO_DISTRIBUIDORA_PRODUTO',
                        key: 'FK_DISTRIBUIDORA',
                        column: 'ID'
                        ]
        produtos joinTable: [
                        name: 'PEDIDO_DISTRIBUIDORA_PRODUTO',
                        key: 'FK_PRODUTOS',
                        column: 'ID'
                        ] 
    }

    static constraints = {
        codigo blank: false, nullable: false, unique: true
        quantidade blank: false, nullable: false
        desconto blank: false, nullable: false
        precoVenda blank: false, nullable: false
    }
}
