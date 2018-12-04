package wgm

class Distribuidora {

    Long id
	String cnpj
	String razaoSocial
	String nomeFantasia
	String endereco
	String telefone

    Usuario usuario

    static hasMany = [
        produtos:Produto
    ]

    static mapping = {
        version false
        usuario cascade: 'all-delete-orphan'
    }

    static constraints = {
        usuario nullable: false, unique: true
        cnpj blank: false, nullable: false
        razaoSocial blank: false, nullable: false
        nomeFantasia blank: false, nullable: false
        endereco blank: false, nullable: false
        telefone blank: false, nullable: false
    }

    String toString() { "$nomeFantasia" }
}
