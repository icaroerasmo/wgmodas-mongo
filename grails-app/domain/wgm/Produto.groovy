package wgm

class Produto {

    Long id
	String ref
	String descricao
	Float largura
	Float altura
	Float profundidade
	String cor
	Float preco
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
        version false
        pedidos joinTable: [
                        name: 'pedido_produto',
                        key: 'produto_id',
                        column: 'id'
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

    String toString() { "$ref" } 
}
