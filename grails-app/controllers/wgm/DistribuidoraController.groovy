package wgm

import grails.validation.ValidationException
import static org.springframework.http.HttpStatus.*

class DistribuidoraController {

    DistribuidoraService distribuidoraService

    static allowedMethods = [save: "POST", update: "PUT", delete: "DELETE"]

    def index(Integer max) {
        params.max = Math.min(max ?: 10, 100)
        respond distribuidoraService.list(params), model:[distribuidoraCount: distribuidoraService.count()]
    }

    def show(Long id) {
        respond distribuidoraService.get(id)
    }

    def create() {
        respond new Distribuidora(params)
    }

    def save(Distribuidora distribuidora) {
        if (distribuidora == null) {
            notFound()
            return
        }

        try {
            distribuidoraService.save(distribuidora)
        } catch (ValidationException e) {
            respond distribuidora.errors, view:'create'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.created.message', args: [message(code: 'distribuidora.label', default: 'Distribuidora'), distribuidora.id])
                redirect distribuidora
            }
            '*' { respond distribuidora, [status: CREATED] }
        }
    }

    def edit(Long id) {
        respond distribuidoraService.get(id)
    }

    def update(Distribuidora distribuidora) {
        if (distribuidora == null) {
            notFound()
            return
        }

        try {
            distribuidoraService.save(distribuidora)
        } catch (ValidationException e) {
            respond distribuidora.errors, view:'edit'
            return
        }

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.updated.message', args: [message(code: 'distribuidora.label', default: 'Distribuidora'), distribuidora.id])
                redirect distribuidora
            }
            '*'{ respond distribuidora, [status: OK] }
        }
    }

    def delete(Long id) {
        if (id == null) {
            notFound()
            return
        }

        distribuidoraService.delete(id)

        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.deleted.message', args: [message(code: 'distribuidora.label', default: 'Distribuidora'), id])
                redirect action:"index", method:"GET"
            }
            '*'{ render status: NO_CONTENT }
        }
    }

    protected void notFound() {
        request.withFormat {
            form multipartForm {
                flash.message = message(code: 'default.not.found.message', args: [message(code: 'distribuidora.label', default: 'Distribuidora'), params.id])
                redirect action: "index", method: "GET"
            }
            '*'{ render status: NOT_FOUND }
        }
    }
}
