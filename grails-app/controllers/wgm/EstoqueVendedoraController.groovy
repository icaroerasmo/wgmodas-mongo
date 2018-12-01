package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class EstoqueVendedoraController {

    EstoqueVendedoraService estoqueVendedoraService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond estoqueVendedoraService.list(params), model:[estoqueVendedoraCount: estoqueVendedoraService.count()]
    }

    def show(Long id) {
        respond estoqueVendedoraService.get(id)
    }

    def create() {
        respond new EstoqueVendedora(params)
    }

    def save(EstoqueVendedora estoqueVendedora) {
        if (estoqueVendedora == null) {
            notFound()
            return
        }

        try {
            estoqueVendedoraService.save(estoqueVendedora)
        } catch (ValidationException e) {
            respond estoqueVendedora.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'estoqueVendedora.label', default: 'EstoqueVendedora'), estoqueVendedora.id])
                redirect estoqueVendedora
            }
            '*' { respond estoqueVendedora, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond estoqueVendedoraService.get(id)
    }

    def update(EstoqueVendedora estoqueVendedora) {
        if (estoqueVendedora == null) {
            notFound()
            return
        }

        try {
            estoqueVendedoraService.save(estoqueVendedora)
        } catch (ValidationException e) {
            respond estoqueVendedora.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'estoqueVendedora.label', default: 'EstoqueVendedora'), estoqueVendedora.id])
                redirect estoqueVendedora
            }
            '*'{ respond estoqueVendedora, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        estoqueVendedoraService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'estoqueVendedora.label', default: 'EstoqueVendedora'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'estoqueVendedora.label', default: 'EstoqueVendedora'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
