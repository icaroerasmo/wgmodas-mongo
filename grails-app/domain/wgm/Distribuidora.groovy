package wgm

class Distribuidora {

    Long id
	String cnpj
	String razaoSocial
	String nomeFantasia
    Usuario usuario

    static hasMany = [
        produtos:Produto,
        pedidos:Pedido
    ]

    static mapping = {
        table 'DISTRIBUIDORA'
        produtos joinTable: [
                        name: 'PEDIDO_DISTRIBUIDORA_PRODUTO',
                        key: 'ID',
                        column: 'FK_PRODUTOS'
                        ] 
        pedidos joinTable: [
                        name: 'PEDIDO_DISTRIBUIDORA_PRODUTO',
                        key: 'ID',
                        column: 'FK_PEDIDO'
                        ]
    }

    static constraints = {
        usuario nullable: false, unique: true
        cnpj blank: false, nullable: false
        razaoSocial blank: false, nullable: false
        nomeFantasia blank: false, nullable: false
    }
}
