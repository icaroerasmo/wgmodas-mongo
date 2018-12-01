package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class VendedoraController {

    VendedoraService vendedoraService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond vendedoraService.list(params), model:[vendedoraCount: vendedoraService.count()]
    }

    def show(Long id) {
        respond vendedoraService.get(id)
    }

    def create() {
        respond new Vendedora(params)
    }

    def save(Vendedora vendedora) {
        if (vendedora == null) {
            notFound()
            return
        }

        try {
            vendedoraService.save(vendedora)
        } catch (ValidationException e) {
            respond vendedora.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'vendedora.label', default: 'Vendedora'), vendedora.id])
                redirect vendedora
            }
            '*' { respond vendedora, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond vendedoraService.get(id)
    }

    def update(Vendedora vendedora) {
        if (vendedora == null) {
            notFound()
            return
        }

        try {
            vendedoraService.save(vendedora)
        } catch (ValidationException e) {
            respond vendedora.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'vendedora.label', default: 'Vendedora'), vendedora.id])
                redirect vendedora
            }
            '*'{ respond vendedora, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        vendedoraService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'vendedora.label', default: 'Vendedora'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'vendedora.label', default: 'Vendedora'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
