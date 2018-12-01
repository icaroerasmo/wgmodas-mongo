package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class ProdutoController {

    ProdutoService produtoService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond produtoService.list(params), model:[produtoCount: produtoService.count()]
    }

    def show(Long id) {
        respond produtoService.get(id)
    }

    def create() {
        respond new Produto(params)
    }

    def save(Produto produto) {
        if (produto == null) {
            notFound()
            return
        }

        try {
            produtoService.save(produto)
        } catch (ValidationException e) {
            respond produto.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'produto.label', default: 'Produto'), produto.id])
                redirect produto
            }
            '*' { respond produto, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond produtoService.get(id)
    }

    def update(Produto produto) {
        if (produto == null) {
            notFound()
            return
        }

        try {
            produtoService.save(produto)
        } catch (ValidationException e) {
            respond produto.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'produto.label', default: 'Produto'), produto.id])
                redirect produto
            }
            '*'{ respond produto, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        produtoService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'produto.label', default: 'Produto'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'produto.label', default: 'Produto'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
