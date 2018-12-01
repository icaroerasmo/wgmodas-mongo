package wgm

class Produto {

    Long id
	String ref
	String descricao
	Double largura
	Double altura
	Double profundidade
	String cor
	Double preco
	String tamanho

    Fabrica fabrica

    static belongsTo = Pedido

    static hasOne = [
        distribuidora:Distribuidora,
    ]

    static hasMany = [
        pedidos:Pedido
    ]

    static mapping = {
        table 'PRODUTO'
        distribuidora joinTable: [
                        name: 'PEDIDO_DISTRIBUIDORA_PRODUTO',
                        key: 'FK_DISTRIBUIDORA',
                        column: 'ID'
                        ]
        pedidos joinTable: [
                        name: 'PEDIDO_DISTRIBUIDORA_PRODUTO',
                        key: 'FK_PEDIDO',
                        column: 'ID'
                        ] 
    }

    static constraints = {
        ref blank: false, nullable: false, unique: true
        descricao blank: false, nullable: false, unique: true
        largura blank: false, nullable: false
        altura blank: false, nullable: false
        profundidade blank: false, nullable: false
        cor blank: false, nullable: false
        preco blank: false, nullable: false
        tamanho blank: true, nullable: true
        fabrica nullable: true, unique: true
    }
}
